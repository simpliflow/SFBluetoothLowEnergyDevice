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



@interface SFBluetoothSmartDeviceManager () {
  __block SMDelayedBlockHandle _connectTimeoutBlock;
  __block SMDelayedBlockHandle _scanForAlternatesTimeoutBlock;
}
@property (nonatomic) dispatch_queue_t bleManagerQueue;

@property (nonatomic) CBCentralManager* bleManager;

@property (nonatomic) NSUUID* identifierToSearchFor;
@property (nonatomic) NSArray* servicesToSearchFor;

@property (nonatomic) CBPeripheral* suitablePeripheral;

@property (nonatomic) BOOL isConnecting;


// Indicates if the central manager should scan
// Necessary because at the time the scanning should be started
// the central may not yet be ready
// Altered internally depending on if a device should be found and
// has been found
@property (nonatomic) BOOL shouldScan;

// Indicates if a device should be found
// Only altered by external triggers: the public methods
// find:advertising:for: and cancelPeripheralConnection:(CBPeripheral*)peripheral;
@property (nonatomic) BOOL findProcessShouldRun;


@property (nonatomic) BOOL connectionAttemptHasTimedOutBefore;

@property (nonatomic) NSMutableDictionary* discoveredPeripherals;


// State of Bluetooth
@property (nonatomic) BOOL bluetoothWasUnavailable;

// # Analytics timing
@property (nonatomic) BOOL isTimingCentralState;
@property (nonatomic) BOOL isTimingDiscoveryTime;
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
  return [NSError errorWithDomain:@"SFBluetoothSmartError"
                             code:errorCode
                         userInfo:@{
                                    NSLocalizedDescriptionKey: @"Error happened"
                                    }];
}




+ (instancetype)deviceManager
{
  return [[SFBluetoothSmartDeviceManager alloc] init];
}


- (id)init
{
  if (self = [super init]) {
    // TODO: make queue a class variable
    _bleManagerQueue = dispatch_queue_create("com.simpliflow_ble_device_central.queue", DISPATCH_QUEUE_SERIAL);
    _bleManager = [[CBCentralManager alloc] initWithDelegate:self queue:_bleManagerQueue];
    self.bluetoothWasUnavailable = NO;
  }
  return self;
}




#pragma Public Methods


- (void)find:(NSUUID*)identifier advertising:(NSArray*)services
{
  dispatch_async(self.bleManagerQueue, ^{
    if (self.findProcessShouldRun == YES) {
      [self cancelConnection];
      dispatch_async(self.bleManagerQueue, ^{[self find:identifier advertising:services];});
      return;
    }
    
    self.findProcessShouldRun = YES;
    
//    NSString* servicesString = [[services valueForKeyPath:@"@unionOfObjects.description"] componentsJoinedByString:@", "];
//    if (identifier)
      // NSLog(@"BLE-Manager: Scanning for peripheral (%@) advertising: %@", identifier, servicesString);
//    else
      // NSLog(@"BLE-Manager: Scanning for any peripheral advertising: %@", servicesString);
    
    self.identifierToSearchFor = identifier;
    self.servicesToSearchFor = services;
    
    self.shouldScan = YES;
    [self startScan];
  });
}


- (void)cancelConnection
{
  // NSLog(@"BLE-Manager: Cancelling connection");
  dispatch_async(self.bleManagerQueue, ^{
    if (self.suitablePeripheral) {
      self.findProcessShouldRun = NO;
      if (self.bleManager.state == CBCentralManagerStatePoweredOn)
        [self.bleManager cancelPeripheralConnection:self.suitablePeripheral];
      self.suitablePeripheral = nil;
      [self invalidateConnectTimer];
    }
    else {
      self.findProcessShouldRun = NO;
      [self stopScan];
      [self invalidateScanForAlternativesTimer];
      [self invalidateConnectTimer];
    }
  });
}




#pragma -
#pragma Private Methods


#pragma Discovery


- (void)startScan
{
  if (self.findProcessShouldRun && self.shouldScan && self.bleManager.state == CBCentralManagerStatePoweredOn) {
    // NSLog(@"BLE-Manager: Starting scan for suitable devices");
    self.connectionAttemptHasTimedOutBefore = NO;
    self.discoveredPeripherals = [@{} mutableCopy];
    [self.bleManager scanForPeripheralsWithServices:self.servicesToSearchFor options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
  }
}


- (void)centralHasDiscoveredPeripheral:(CBPeripheral*)peripheral RSSI:(NSNumber*)RSSI
{
  if ([self.identifierToSearchFor isEqual:peripheral.identifier]) {
    [self stopScan];
    
    self.suitablePeripheral = peripheral;
    // NSLog(@"Did discover suitable peripheral: %@", peripheral);
    
    [self connectToSuitablePeripheral];
  }
  else if (!self.identifierToSearchFor) {
    if (self.discoveredPeripherals.count == 0) {
      [self startScanForAlternatesTimer];
    }
    
    self.discoveredPeripherals[peripheral] = RSSI;
    
    // NSLog(@"BLE-Manager: Did discover suitable peripheral %@ with RSSI %@", peripheral, RSSI);
  }
  else {
    // NSLog(@"BLE-Manager: Did discover unsuitable peripheral: %@", peripheral);
  }
}


- (void)startScanForAlternatesTimer
{
  _scanForAlternatesTimeoutBlock = perform_block_after_delay(SCAN_FOR_ALTERNATES_TIMEOUT, self.bleManagerQueue, ^{
    [self scanForAlternatesTimedOut];
  });
}


- (void)scanForAlternatesTimedOut
{
  // NSLog(@"BLE-Manager: Finished scanning for alternates, found %d peripherals.", self.discoveredDevices.count);
  [self stopScan];
  [self invalidateScanForAlternativesTimer];
  
  CBPeripheral* peripheralWithStrongestRSSI = nil;
  NSArray* sortedPeripherals = [self.discoveredPeripherals keysSortedByValueUsingComparator:^(NSNumber* RSSI1, NSNumber* RSSI2){return [RSSI1 compare:RSSI2];}];
  
  if (self.discoveredPeripherals.count > 1) {
    NSNumber* bestRSSI = self.discoveredPeripherals[sortedPeripherals[0]];
    NSNumber* secondBestRSSI = self.discoveredPeripherals[sortedPeripherals[1]];
    if (bestRSSI.floatValue - secondBestRSSI.floatValue < RSSI_DIFFERENCE_THRESHOLD) {
      // report "undistinguishable"-error
      [self.delegate managerFailedToConnectToSuitablePeripheral:self error:[SFBluetoothSmartDeviceManager error:SFBluetoothSmartErrorUnableToDistinguishClosestDevice]];
      [self startScan];
      return;
      // return
    }
  }
  
  peripheralWithStrongestRSSI = sortedPeripherals[0];
  self.suitablePeripheral = peripheralWithStrongestRSSI;
  
  [self connectToSuitablePeripheral];
}


- (void)invalidateScanForAlternativesTimer
{
  if (_scanForAlternatesTimeoutBlock) {
    cancel_delayed_block(_scanForAlternatesTimeoutBlock);
    _scanForAlternatesTimeoutBlock = nil;
  }
}


- (void)stopScan
{
  // NSLog(@"BLE-Manager: Stopping scan");
  self.shouldScan = NO;
  
  if (self.bleManager.state == CBCentralManagerStatePoweredOn)
    [self.bleManager stopScan];
}




#pragma Connecting


- (void)connectToSuitablePeripheral
{
  [self startConnectTimer];
  [self.bleManager connectPeripheral:self.suitablePeripheral options:nil];
}


- (void)startConnectTimer
{
  _connectTimeoutBlock = perform_block_after_delay(CONNECT_TIMEOUT, self.bleManagerQueue, ^{
    [self connectTimedOut];
  });
}


- (void)centralConnectedSuccessfully
{
  // NSLog(@"BLE-Manager: connected to %@", self.suitablePeripheral.name);
  [self invalidateConnectTimer];
  [self.delegate manager:self connectedToSuitablePeripheral:self.suitablePeripheral];
}


- (void)invalidateConnectTimer
{
  cancel_delayed_block(_connectTimeoutBlock);
  _connectTimeoutBlock = nil;
}


- (void)connectTimedOut
{
  [self invalidateConnectTimer];
  
  // the connection does not time out automatically, we have to do this expicitly
  [self.bleManager cancelPeripheralConnection:self.suitablePeripheral];
  
  [self.delegate managerFailedToConnectToSuitablePeripheral:self error:nil];
  self.suitablePeripheral = nil;
  self.shouldScan = YES;
  [self startScan];
}

                                                                            


#pragma CBCentralManagerDelegate


- (void)centralManagerDidUpdateState:(CBCentralManager*)central
{
  // NSLog(@"BLE-Manager: Central did update state to %@", __managerStateStrings[central.state]);
  if (central.state == CBCentralManagerStatePoweredOn) {
    
//    if (self.isTimingCentralState) {
//      self.isTimingDiscoveryTime = NO;
//    }
    [self startScan];
    
    if (self.bluetoothWasUnavailable && [self.delegate respondsToSelector:@selector(bluetoothAvailableAgain)])
      [self.delegate bluetoothAvailableAgain];
  }
  else if (central.state == CBCentralManagerStatePoweredOff ||
           central.state == CBCentralManagerStateUnsupported ||
           central.state == CBCentralManagerStateUnauthorized) {
    [self invalidateConnectTimer];
    if (self.suitablePeripheral)
      [self.bleManager cancelPeripheralConnection:self.suitablePeripheral];
    
    self.suitablePeripheral = nil;
    [self invalidateScanForAlternativesTimer];
    
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
  // NSLog(@"BLE-Manager: --  %@: central failed to connect to (%@).", peripheral.name, error.localizedDescription);
  [self invalidateConnectTimer];
  
  self.suitablePeripheral = nil;
  self.shouldScan = YES;
  [self startScan];
}


- (void)centralManager:(CBCentralManager*)central didDisconnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error
{
  if (error) {
    // in case of a timeout, try a second time before reporting a failed attempt
    if (error.code == 6 && !self.connectionAttemptHasTimedOutBefore) {
      [self invalidateConnectTimer];
      // NSLog(@"BLE-Manager: Connection has timed out. Trying a second time");
      self.connectionAttemptHasTimedOutBefore = YES;
      [self connectToSuitablePeripheral];
      return;
    }
    
    // NSLog(@"BLE-Manager: -- %@: central disconnected with error (%@).", peripheral.name, error.localizedDescription);
  }
  else {
    // NSLog(@"BLE-Manager: %@: central disconnected (no error).", peripheral.name);
  }
  
  [self.delegate manager:self disconnectedFromPeripheral:peripheral];
  self.shouldScan = YES;
  [self startScan];
}
                                                                            
                                                                            
@end

#undef RSSI_DIFFERENCE_THRESHOLD
#undef SCAN_FOR_ALTERNATES_TIMEOUT
#undef CONNECT_TIMEOUT
