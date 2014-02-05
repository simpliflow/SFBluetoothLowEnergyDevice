//
//  SFBluetoothSmartDeviceManager.m
//  SFBluetoothSmartDevice
//
//  Created by Thomas Billicsich on 14.01.14.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//


#define CONNECT_TIMEOUT 1.5
#define SCAN_FOR_ALTERNATES_TIMEOUT 4

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

@property (nonatomic) NSMutableDictionary* discoveredDevices;


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
    
    NSString* servicesString = [[services valueForKeyPath:@"@unionOfObjects.description"] componentsJoinedByString:@", "];
    if (identifier)
      NSLog(@"Scanning for peripheral (%@) advertising: %@", identifier, servicesString);
    else
      NSLog(@"Scanning for any peripheral advertising: %@", servicesString);
    
    self.identifierToSearchFor = identifier;
    self.servicesToSearchFor = services;
    
    self.shouldScan = YES;
    [self startScan];
  });
}


- (void)cancelConnection
{
  NSLog(@"Cancelling connection");
  if (self.suitablePeripheral) {
    dispatch_async(self.bleManagerQueue, ^{
      self.findProcessShouldRun = NO;
      if (self.bleManager.state == CBCentralManagerStatePoweredOn)
        [self.bleManager cancelPeripheralConnection:self.suitablePeripheral];
      self.suitablePeripheral = nil;
    });
  }
  else {
    dispatch_async(self.bleManagerQueue, ^{
      self.findProcessShouldRun = NO;
      [self stopScan];
      [self cancelScanForAlternativesTimer];
      [self invalidateConnectTimer];
    });
  }
}




#pragma -
#pragma Private Methods


#pragma Discovery


- (void)startScan
{
  if (self.findProcessShouldRun && self.shouldScan && self.bleManager.state == CBCentralManagerStatePoweredOn) {
    NSLog(@"Starting scan for suitable devices");
    self.connectionAttemptHasTimedOutBefore = NO;
    self.discoveredDevices = [@{} mutableCopy];
    [self.bleManager scanForPeripheralsWithServices:self.servicesToSearchFor options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
  }
}


- (void)centralHasDiscoveredPeripheral:(CBPeripheral*)peripheral RSSI:(NSNumber*)RSSI
{
  if ([self.identifierToSearchFor isEqual:peripheral.identifier]) {
    [self stopScan];
    
    self.suitablePeripheral = peripheral;
    NSLog(@"Did discover suitable peripheral: %@", peripheral);
    
    [self connectToSuitablePeripheral];
  }
  else if (!self.identifierToSearchFor) {
    if (self.discoveredDevices.count == 0) {
      [self startScanForAlternatesTimer];
    }
    
    self.discoveredDevices[RSSI] = peripheral;
    
    NSLog(@"Did discover suitable peripheral %@ with RSSI %@", peripheral, RSSI);
  }
  else {
    NSLog(@"Did discover unsuitable peripheral: %@", peripheral);
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
  NSLog(@"Finished scanning for alternates, found %d peripherals.", self.discoveredDevices.count);
  [self stopScan];
  [self cancelScanForAlternativesTimer];
  
  NSNumber* strongestRSSI = [self.discoveredDevices.allKeys valueForKeyPath:@"@max.intValue"];
  CBPeripheral* peripheralWithStrongestRSSI = self.discoveredDevices[strongestRSSI];
  self.suitablePeripheral = peripheralWithStrongestRSSI;
  
  [self connectToSuitablePeripheral];
}

// TODO: rename to "invalidate..."
- (void)cancelScanForAlternativesTimer
{
  if (_scanForAlternatesTimeoutBlock) {
    cancel_delayed_block(_scanForAlternatesTimeoutBlock);
    _scanForAlternatesTimeoutBlock = nil;
  }
}


- (void)stopScan
{
  NSLog(@"Stopping scan");
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
  NSLog(@"%@: central connected", self.suitablePeripheral.name);
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
  NSLog(@"Central did update state to %@", __managerStateStrings[central.state]);
  if (central.state == CBCentralManagerStatePoweredOn) {
    
    if (self.isTimingCentralState) {
      self.isTimingDiscoveryTime = NO;
    }
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
    [self cancelScanForAlternativesTimer];
    
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
  NSLog(@"--  %@: central failed to connect to (%@).", peripheral.name, error.localizedDescription);
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
      NSLog(@"Connection has timed out. Trying a second time");
      self.connectionAttemptHasTimedOutBefore = YES;
      [self connectToSuitablePeripheral];
      return;
    }
    
    NSLog(@"-- %@: central disconnected with error (%@).", peripheral.name, error.localizedDescription);
  }
  else {
    NSLog(@"%@: central disconnected (no error).", peripheral.name);
  }
  
  [self.delegate manager:self disconnectedFromPeripheral:peripheral];
  self.shouldScan = YES;
  [self startScan];
}


@end

#undef SCAN_FOR_ALTERNATES_TIMEOUT
#undef CONNECT_TIMEOUT
