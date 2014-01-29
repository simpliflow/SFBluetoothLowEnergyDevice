//
//  SFBLEPeripheralDelegate.m
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.


#import "SFBLEPeripheralDelegate.h"
#import "Log4Cocoa.h"
#import "SpacemanBlocks.h"

#import "SFBLEDeviceManager.h"
#import "SFBLEDevice.h"


#define DISCOVERY_TIMEOUT 2.0




@interface SFBLEPeripheralDelegate () {
  __block SMDelayedBlockHandle _discoveryTimeoutBlock;
}

@property (nonatomic, assign) SFBLEDevice* device;
@property (nonatomic) NSDictionary* servicesAndCharacteristics;

@property (nonatomic) NSMutableDictionary* characteristicsByUUID;
@property (nonatomic) NSMutableDictionary* servicesByUUID;

@end




@implementation SFBLEPeripheralDelegate


+ (instancetype)peripheralDelegateWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics forDevice:(SFBLEDevice*)device
{
  return [[SFBLEPeripheralDelegate alloc] initWithServicesAndCharacteristics:servicesAndCharacteristics forDevice:device];
}
- (id)initWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics forDevice:(SFBLEDevice*)device
{
  if (self = [super init]) {
    // No need to check here, as it has already been checked on SFBLEDeviceManager-init
    _servicesAndCharacteristics = servicesAndCharacteristics;
    _device = device;
    device.peripheral.delegate = self;
  }
  return self;
}


- (CBCharacteristic*)characteristic:(CBUUID*)characteristicUUID
{
  return self.characteristicsByUUID[characteristicUUID];
}


- (CBService*)service:(CBUUID*)serviceUUID
{
  return self.servicesByUUID[serviceUUID];
}




#pragma mark -
#pragma mark Discovering


- (void)startDiscovering
{
  self.characteristicsByUUID = [@{} mutableCopy];
  self.servicesByUUID = [@{} mutableCopy];
  [self.device.peripheral discoverServices:self.servicesAndCharacteristics.allKeys];
  [self startDiscoveryTimer];
}


- (void)startDiscoveryTimer
{
  _discoveryTimeoutBlock = perform_block_after_delay(DISCOVERY_TIMEOUT, SFBLEDeviceManager.bleQueue, ^{
    [self discoveryTimedOut];
  });
}


- (void)invalidateDiscoveryTimer
{
  if (_discoveryTimeoutBlock) {
    cancel_delayed_block(_discoveryTimeoutBlock);
    _discoveryTimeoutBlock = nil;
  }
}


- (void)discoveryTimedOut
{
  log4Debug(@"BLE-PeripheralDelegate: discovery timed out");
  [self invalidateDiscoveryTimer];
  [self.device discoveryTimedOut];
}


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverServices:(NSError*)error
{
  NSArray* services = peripheral.services;
  
  for (CBService* service in services) {
    NSArray* characteristicsToDiscover = self.servicesAndCharacteristics[service.UUID];
    log4Debug(@"BLE-PeripheralDelegate: starting characteristic discovery for service %@: %@", service.UUID, [[characteristicsToDiscover valueForKeyPath:@"description"] componentsJoinedByString:@", "]);
    [peripheral discoverCharacteristics:characteristicsToDiscover forService:service];
  }
}


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverCharacteristicsForService:(CBService*)service error:(NSError*)error
{
  if (error) {
    log4Info(@"BLE-PeripheralDelegate: error in characteristic discovery: %@ %@", [error localizedDescription], error);
    return;
  }
  
  log4Debug(@"BLE-PeripheralDelegate: did discover characteristics for service %@", service.UUID);

  self.servicesByUUID[service.UUID] = service;
  
  for (CBCharacteristic* characteristic in service.characteristics) {
    self.characteristicsByUUID[characteristic.UUID] = characteristic;
  }
  NSArray* charsOfService = self.servicesAndCharacteristics[service.UUID];
  if (charsOfService.count != service.characteristics.count) {
    // TODO: abort, inconsistency between discovered and prescribed characteristics in service
  }
  
  if (self.servicesByUUID.count == self.servicesAndCharacteristics.count) {
    [self completedDiscovery];
  }
}


- (void)completedDiscovery
{
  [self invalidateDiscoveryTimer];
  [self.device completedDiscovery];
}




#pragma mark -
#pragma mark Data Transmission


- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID
{
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.device.peripheral readValueForCharacteristic:characteristic];
}


- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID
{
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.device.peripheral setNotifyValue:YES forCharacteristic:characteristic];
}


- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID
{
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.device.peripheral setNotifyValue:NO forCharacteristic:characteristic];
}


- (void)peripheral:(CBPeripheral*)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error
{
  if (error) {
    log4Warn(@"BLE-PeripheralDelegate: updated notification state with error: %@", [error localizedDescription], error);
    return;
  }
}


- (void)peripheral:(CBPeripheral*)peripheral didUpdateValueForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error
{
  if (error) {
    log4Warn(@"error: %@ %@", [error localizedDescription], error);
    return;
  }
  
  [self.device didUpdateValueForCharacteristic:characteristic error:error];
}


@end


#undef DISCOVERY_TIMEOUT
