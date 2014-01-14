//
//  SFBluetoothSmartDeviceManager.m
//  SFBluetoothSmartDevice
//
//  Created by Thomas Billicsich on 14.01.14.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//


#define CONNECT_TIME_OUT_INTERVAL 1.5

#import "SFBluetoothSmartDeviceManager.h"
#import "SpacemanBlocks.h"



@interface SFBluetoothSmartDeviceManager () {
  __block SMDelayedBlockHandle _connectTimeoutBlock;
  __block SMDelayedBlockHandle _scanTimeoutBlock;
}
@property (nonatomic) CBCentralManager* bleManager;
@property (nonatomic) dispatch_queue_t bleManagerQueue;
@property (nonatomic) NSUUID* identifierToSearchFor;
@property (nonatomic) id<SFBluetoothSmartDeviceManagerDelegate> delegateForIdentifier;
@property (nonatomic) NSArray* servicesToSearchFor;
@property (nonatomic) CBPeripheral* suitablePeripheral;
@property (nonatomic) BOOL shouldScan;
@property (nonatomic) BOOL connectionAttemptHasTimedOutBefore;

// Timing
@property (nonatomic) BOOL isTimingCentralState;
@property (nonatomic) BOOL isTimingDiscoveryTime;
@end





@implementation SFBluetoothSmartDeviceManager


static NSArray* __managerStateStrings;
+ (void)initialize
{
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
    self.isTimingCentralState = YES;
    self.timeout = 10.0;
  }
  return self;
}




#pragma Public Methods


- (void)find:(NSUUID*)identifier advertising:(NSArray*)services for:(id<SFBluetoothSmartDeviceManagerDelegate>)delegate
{
  dispatch_async(self.bleManagerQueue, ^{
    
    if (identifier)
      NSLog(@"Scanning for peripheral (%@) advertising: %@", identifier, services);
    else
      NSLog(@"Scanning for any peripheral advertising: %@", services);
    
    self.identifierToSearchFor = identifier;
    self.servicesToSearchFor = services;
    self.shouldScan = YES;
    self.delegateForIdentifier = delegate;
    
    [self startScan];
    [self startScanTimer];
  });
}


- (void)cancelPeripheralConnection:(CBPeripheral*)peripheral
{
  if (peripheral) {
    dispatch_async(self.bleManagerQueue, ^{
      if (self.bleManager.state == CBCentralManagerStatePoweredOn)
        [self.bleManager cancelPeripheralConnection:peripheral];
      
      [self stopScanTimer];
    });
  }
  else {
    dispatch_async(self.bleManagerQueue, ^{
      [self stopScanTimer];
    });
  }
}




#pragma Private Methods


- (void)startScan
{
  if (self.shouldScan && self.bleManager.state == CBCentralManagerStatePoweredOn) {
    NSLog(@"Starting scan for suitable devices");
    self.connectionAttemptHasTimedOutBefore = NO;
    [self.bleManager scanForPeripheralsWithServices:self.servicesToSearchFor options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @NO}];
    self.isTimingDiscoveryTime = YES;
  }
}


- (void)startScanTimer
{
  _scanTimeoutBlock = perform_block_after_delay(self.timeout, self.bleManagerQueue, ^{
    [self scanTimedOut];
  });
}


- (void)stopScanTimer
{
  NSLog(@"Stopping Scan");
  cancel_delayed_block(_scanTimeoutBlock);
  _scanTimeoutBlock = nil;

  if (self.isTimingDiscoveryTime) {
    self.isTimingDiscoveryTime = NO;
  }

  if (self.bleManager.state == CBCentralManagerStatePoweredOn)
    [self.bleManager stopScan];
}


- (void)scanTimedOut
{
  NSLog(@"Scan timed out");
  [self stopScanTimer];
  [self.delegateForIdentifier managerFailedToConnectToSuitablePeripheral:self];
  self.identifierToSearchFor = nil;
}



- (void)startConnectTimer
{
  _connectTimeoutBlock = perform_block_after_delay(CONNECT_TIME_OUT_INTERVAL, self.bleManagerQueue, ^{
    [self connectTimedOut];
  });
}


- (void)stopConnectTimer
{
  cancel_delayed_block(_connectTimeoutBlock);
  _connectTimeoutBlock = nil;
}


- (void)connectTimedOut
{
  [self stopConnectTimer];
  [self.delegateForIdentifier managerFailedToConnectToSuitablePeripheral:self];
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
  }
}


- (void)centralManager:(CBCentralManager*)central didDiscoverPeripheral:(CBPeripheral*)peripheral advertisementData:(NSDictionary*)advertisementData RSSI:(NSNumber*)RSSI
{
  if (!self.identifierToSearchFor || [self.identifierToSearchFor isEqual:peripheral.identifier]) {
    [self stopScanTimer];
    self.suitablePeripheral = peripheral;
    [self startConnectTimer];
    [self.bleManager connectPeripheral:peripheral options:nil];
    NSLog(@"Did discover suitable peripheral: %@", peripheral);
  }
  else {
    NSLog(@"Did discover unsuitable peripheral: %@", peripheral);
  }
}


- (void)centralManager:(CBCentralManager*)central didConnectPeripheral:(CBPeripheral*)peripheral
{
  NSLog(@"%@: central connected", peripheral.name);
  [self stopConnectTimer];
  [self.delegateForIdentifier manager:self connectedToSuitablePeripheral:peripheral];
  self.suitablePeripheral = nil;
  self.identifierToSearchFor = nil;
}


- (void)centralManager:(CBCentralManager*)central didFailToConnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error
{
  NSLog(@"--  %@: central failed to connect to (%@).", peripheral.name, error.localizedDescription);
  [self stopConnectTimer];
  [self.delegateForIdentifier managerFailedToConnectToSuitablePeripheral:self];
  self.suitablePeripheral = nil;
  self.identifierToSearchFor = nil;
}


- (void)centralManager:(CBCentralManager*)central didDisconnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error
{

  if (error) {
    // in case of a timeout, try a second time before reporting a failed attempt
    if (error.code == 6 && !self.connectionAttemptHasTimedOutBefore) {
      NSLog(@"Connection has timed out. Trying a second time");
      self.connectionAttemptHasTimedOutBefore = YES;
      self.suitablePeripheral = peripheral;
      [self startConnectTimer];
      [self.bleManager connectPeripheral:self.suitablePeripheral options:nil];
      return;
    }
    
    NSLog(@"-- %@: central disconnected with error (%@).", peripheral.name, error.localizedDescription);
  }
  else {
    NSLog(@"%@: central disconnected (no error).", peripheral.name);
  }
  
  [self.delegateForIdentifier manager:self disconnectedFromPeripheral:peripheral];
}


@end
