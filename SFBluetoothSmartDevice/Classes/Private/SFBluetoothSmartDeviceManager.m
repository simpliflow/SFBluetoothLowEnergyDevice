//
//  SFBluetoothSmartDeviceManager.m
//  SFBluetoothSmartDevice
//
//  Created by Thomas Billicsich on 14.01.14.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//


#define CONNECT_TIMEOUT 1.5
#define SCAN_FOR_ALTERNATES_TIMEOUT 2
#define RSSI_DIFFERENCE_THRESHOLD 10

#import "SFBluetoothSmartDeviceManager.h"
#import "SpacemanBlocks.h"
#import "Log4Cocoa.h"


@interface SFBluetoothSmartDeviceManager () {
  __block SMDelayedBlockHandle _connectTimeoutBlock;
  __block SMDelayedBlockHandle _scanForAlternatesTimeoutBlock;
}

@property (readwrite) dispatch_queue_t bleManagerQueue;
@property (nonatomic) CBCentralManager* bleManager;

@property (nonatomic) CBPeripheral* suitablePeripheral;


@property (nonatomic) BOOL isScanning;
@property (nonatomic) BOOL isConnecting;


// Indicates if the central manager should scan
// Necessary because at the time the scanning should be started
// the central may not yet be ready
// Altered internally depending on if a device should be found and
// has been found
@property (nonatomic) BOOL shouldScan;
@property (nonatomic) NSUUID* identifierToScanFor;
@property (nonatomic) NSArray* servicesToScanFor;


// Dict to hold the peripherals' RSSIs during scanning for alternatives.
// Peripherals are the keys, RSSIs are saved to a mutable array, after
// scanning has finished the average is calculated.
@property (nonatomic) NSMutableDictionary* discoveredPeripherals;


// State of Bluetooth
@property (nonatomic) BOOL bluetoothWasUnavailable;


// Special: connections often time out and can be successful on second try
@property (nonatomic) BOOL connectionAttemptHasTimedOutBefore;



@end





@implementation SFBluetoothSmartDeviceManager


static NSArray* __managerStateStrings;
+ (void)initialize
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    if (self == [SFBluetoothSmartDeviceManager class]) {
      __managerStateStrings = @[
                                @"Unknown",
                                @"Resetting",
                                @"Unsupported",
                                @"Unauthorized",
                                @"PoweredOff",
                                @"PoweredOn"
                                ];
      
    }
  });
}


+ (NSError*)error:(SFBluetoothSmartError)errorCode
{
  NSString* description = nil;
  switch (errorCode) {
    case 0:
      description = @"Unable to distinguish closest device";
      break;
    case 1:
      description = @"Problems in connection process";
      break;
    case 2:
      description = @"Problems in discovery process";
      break;
    case 3:
      description = @"Connection closed by device";
      break;
    case 4:
      description = @"Other CoreBluetooth error";
      break;
    case 5:
      description = @"Unknown error";
      break;
      
    default:
      break;
  }
  
  return [NSError errorWithDomain:@"SFBluetoothSmartError"
                             code:errorCode
                         userInfo:@{
                                    NSLocalizedDescriptionKey:description
                                    }];
}




+ (instancetype)deviceManager
{
  return [[SFBluetoothSmartDeviceManager alloc] init];
}


- (id)init
{
  if (self = [super init]) {
    _bleManagerQueue = dispatch_queue_create("com.simpliflow_ble_device_central.queue", DISPATCH_QUEUE_SERIAL);
    _bleManager = [[CBCentralManager alloc] initWithDelegate:self queue:_bleManagerQueue];
    self.bluetoothWasUnavailable = NO;
  }
  return self;
}




#pragma mark -
#pragma mark # Public Methods


- (void)search:(NSUUID*)identifier advertising:(NSArray*)services
{
  NSString* servicesString = [[services valueForKeyPath:@"@unionOfObjects.description"] componentsJoinedByString:@", "];
  if (identifier) {
    log4Debug(@"BLE-Manager: starts finding of peripheral (%@) advertising: %@", identifier, servicesString);
  }
  else {
    log4Debug(@"BLE-Manager: starts finding of any peripheral advertising: %@", servicesString);
  }
  
  self.identifierToScanFor = identifier;
  self.servicesToScanFor = services;
  
  self.shouldScan = YES;
  [self startScan];
}


- (void)cancelConnection
{
  log4Debug(@"BLE-Manager: cancelling connection");
  [self stopScan];
  [self invalidateScanForAlternativesTimer];
  [self invalidateConnectTimer];

  if (self.suitablePeripheral) {
    if (self.bleManager.state == CBCentralManagerStatePoweredOn)
      [self.bleManager cancelPeripheralConnection:self.suitablePeripheral];
    self.suitablePeripheral = nil;
  }
}




#pragma mark -
#pragma mark # Private Methods


#pragma mark -
#pragma mark Scanning


- (void)startScan
{
  if (self.shouldScan && self.bleManager.state == CBCentralManagerStatePoweredOn) {
    log4Debug(@"BLE-Manager: starting scan for suitable devices");
    self.connectionAttemptHasTimedOutBefore = NO;
    self.discoveredPeripherals = [@{} mutableCopy];
    [self.bleManager scanForPeripheralsWithServices:self.servicesToScanFor options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
  }
}


- (void)stopScan
{
  log4Debug(@"BLE-Manager: stopping scan");
  self.shouldScan = NO;
  
  if (self.bleManager.state == CBCentralManagerStatePoweredOn)
    [self.bleManager stopScan];
}


- (void)centralHasDiscoveredPeripheral:(CBPeripheral*)peripheral RSSI:(NSNumber*)RSSI
{
  NSAssert(self.shouldScan, @"Race condition");
  
  // An RSSI value of 127 is not valid, but it has been encountered regularly
  if (RSSI.integerValue == 127)
    return;
  
  if ([self.identifierToScanFor isEqual:peripheral.identifier]) {
    [self stopScan];
    
    log4Debug(@"BLE-Manager: Did discover suitable peripheral: %@", peripheral);
    [self connectToSuitablePeripheral:peripheral];
  }
  else if (!self.identifierToScanFor) {
    if (self.discoveredPeripherals.count == 0) {
      [self startScanForAlternatesTimer];
    }
    if (![self.discoveredPeripherals.allKeys containsObject:peripheral]) {
      self.discoveredPeripherals[peripheral] = [@[RSSI] mutableCopy];
      log4Info(@"BLE-Manager: New suitable peripheral %p (%@, %@). RSSI: %@", peripheral, peripheral.identifier, peripheral.name, RSSI);
    }
    else {
      log4Debug(@"BLE-Manager: Old suitable peripheral %p. RSSI: %@", peripheral, RSSI);
      NSMutableArray* RSSIs = self.discoveredPeripherals[peripheral];
      [RSSIs addObject:RSSI];
    }
  }
  else {
    log4Debug(@"BLE-Manager: Did discover unsuitable peripheral: %@", peripheral);
  }
}


- (void)startScanForAlternatesTimer
{
  _scanForAlternatesTimeoutBlock = perform_block_after_delay(SCAN_FOR_ALTERNATES_TIMEOUT, self.bleManagerQueue, ^{
    [self scanForAlternatesTimedOut];
  });
}


- (void)invalidateScanForAlternativesTimer
{
  if (_scanForAlternatesTimeoutBlock) {
    cancel_delayed_block(_scanForAlternatesTimeoutBlock);
    _scanForAlternatesTimeoutBlock = nil;
  }
}


- (void)scanForAlternatesTimedOut
{
  log4Debug(@"BLE-Manager: finished scanning for alternates, found %d peripherals.", self.discoveredPeripherals.count);
  [self stopScan];
  [self invalidateScanForAlternativesTimer];
  
  
  NSMutableDictionary* discoveredPerphs = self.discoveredPeripherals;
  
  // Calculate the average of all RSSIs and sort the peripherals by result
  for (NSString* peripheral in discoveredPerphs.allKeys) {
    discoveredPerphs[peripheral] = [discoveredPerphs[peripheral] valueForKeyPath:@"@avg.self"];
  }
  NSArray* sortedPeripherals = [discoveredPerphs keysSortedByValueUsingComparator:^(NSNumber* RSSI1, NSNumber* RSSI2){return [RSSI2 compare:RSSI1];}];
  log4Debug(@"%@", discoveredPerphs);
  
  // Check if the first two are very close or take the first one
  CBPeripheral* peripheralWithStrongestRSSI = nil;
  if (discoveredPerphs.count > 1) {
    NSNumber* bestRSSI = discoveredPerphs[sortedPeripherals[0]];
    NSNumber* secondBestRSSI = discoveredPerphs[sortedPeripherals[1]];
    if (bestRSSI.floatValue - secondBestRSSI.floatValue < RSSI_DIFFERENCE_THRESHOLD) {
      NSAssert(!self.suitablePeripheral, @"Prior to this method a suitable peripheral should not have been assigned.");
      [self.delegate managerFailedToConnectToSuitablePeripheral:sortedPeripherals[0] error:[SFBluetoothSmartDeviceManager error:SFBluetoothSmartErrorUnableToDistinguishClosestDevice]];
      return;
    }
  }
  
  peripheralWithStrongestRSSI = sortedPeripherals[0];
  log4Info(@"BLE-Manager: Did choose suitable peripheral: %p", peripheralWithStrongestRSSI);
  [self connectToSuitablePeripheral:peripheralWithStrongestRSSI];
}




#pragma mark -
#pragma mark Connecting


- (void)connectToSuitablePeripheral:(CBPeripheral*)peripheral
{
  log4Debug(@"BLE-Manager: starting connect to suitable peripheral: %@", peripheral);
  self.suitablePeripheral = peripheral;
  
  [self startConnectTimer];
  [self.bleManager connectPeripheral:self.suitablePeripheral options:nil];
}


- (void)startConnectTimer
{
  _connectTimeoutBlock = perform_block_after_delay(CONNECT_TIMEOUT, self.bleManagerQueue, ^{
    [self connectTimedOut];
  });
}


- (void)invalidateConnectTimer
{
  if (_connectTimeoutBlock) {
    cancel_delayed_block(_connectTimeoutBlock);
    _connectTimeoutBlock = nil;
  }
}


- (void)connectTimedOut
{
  NSAssert(self.suitablePeripheral, @"Race condition");
  
  log4Info(@"BLE-Manager: connect timed out. Reporting error.");
  [self invalidateConnectTimer];
  
  // the connection does not time out automatically, we have to do this expicitly
  [self.bleManager cancelPeripheralConnection:self.suitablePeripheral];
  
  CBPeripheral* peripheral = self.suitablePeripheral;
  self.suitablePeripheral = nil;
  [self.delegate managerFailedToConnectToSuitablePeripheral:peripheral error:nil];
}


- (void)centralConnectedSuccessfully
{
  NSAssert(self.suitablePeripheral, @"Race condition");
  
  log4Debug(@"BLE-Manager: connected to %@", self.suitablePeripheral.name);
  [self invalidateConnectTimer];
  
  [self.delegate managerConnectedToSuitablePeripheral:self.suitablePeripheral];
}


- (void)centralFailedToConnect:(NSError*)error
{
  NSAssert(self.suitablePeripheral, @"Race condition");
  
  log4Info(@"BLE-Manager: failed to connect to %@", self.suitablePeripheral.name);
  [self invalidateConnectTimer];
  
  CBPeripheral* peripheral = self.suitablePeripheral;
  self.suitablePeripheral = nil;
  
  NSError* sfError = nil;
  if (error) {
    NSString* localizedDescription = [NSString stringWithFormat:@"%@: %@", @(error.code), error.localizedDescription];
    sfError = [SFBluetoothSmartDeviceManager error:SFBluetoothSmartErrorOtherCBError];
    sfError = [NSError errorWithDomain:sfError.domain code:sfError.code userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
  }
  
  [self.delegate managerFailedToConnectToSuitablePeripheral:peripheral error:sfError];
}




#pragma mark -
#pragma mark Connected


- (void)centralDisconnected:(NSError*)error
{
  if (error) {
    log4Info(@"BLE-Manager: disconnected from %@ with error (%@: %@).", self.suitablePeripheral.name, error.domain, error.localizedDescription);
  }
  else {
    log4Debug(@"BLE-Manager: disconnected from %@", self.suitablePeripheral.name);
  }
  
  CBPeripheral* peripheral = self.suitablePeripheral;
  self.suitablePeripheral = nil;
  [self.delegate managerDisconnectedFromPeripheral:peripheral error:error];
}




#pragma mark -
#pragma mark CBCentralManagerDelegate


- (void)centralManagerDidUpdateState:(CBCentralManager*)central
{
  log4Debug(@"BLE-Manager: central updated state to %@", __managerStateStrings[central.state]);

  if (central.state == CBCentralManagerStatePoweredOn)
  {
    [self startScan];
    
    if (self.bluetoothWasUnavailable && [self.delegate respondsToSelector:@selector(bluetoothAvailableAgain)])
      [self.delegate bluetoothAvailableAgain];
  }
  
  else if (central.state == CBCentralManagerStatePoweredOff ||
           central.state == CBCentralManagerStateUnsupported ||
           central.state == CBCentralManagerStateUnauthorized)
  {
    [self invalidateScanForAlternativesTimer];
    [self invalidateConnectTimer];

    if (self.suitablePeripheral) {
      [self.bleManager cancelPeripheralConnection:self.suitablePeripheral];
      self.suitablePeripheral = nil;
    }
    
    if ([self.delegate respondsToSelector:@selector(bluetoothNotAvailable)])
      [self.delegate bluetoothNotAvailable];
    self.bluetoothWasUnavailable = YES;
  }
}


- (void)centralManager:(CBCentralManager*)central didDiscoverPeripheral:(CBPeripheral*)peripheral advertisementData:(NSDictionary*)advertisementData RSSI:(NSNumber*)RSSI
{
  [self centralHasDiscoveredPeripheral:peripheral RSSI:RSSI];
}


- (void)centralManager:(CBCentralManager*)central didConnectPeripheral:(CBPeripheral*)peripheral
{
  NSAssert(peripheral == self.suitablePeripheral, @"Connected to a different than the suitable peripheral");
  
  [self centralConnectedSuccessfully];
}


- (void)centralManager:(CBCentralManager*)central didFailToConnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error
{
  [self centralFailedToConnect:error];
}


- (void)centralManager:(CBCentralManager*)central didDisconnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error
{
  [self centralDisconnected:error];
}


@end




#undef RSSI_DIFFERENCE_THRESHOLD
#undef SCAN_FOR_ALTERNATES_TIMEOUT
#undef CONNECT_TIMEOUT
