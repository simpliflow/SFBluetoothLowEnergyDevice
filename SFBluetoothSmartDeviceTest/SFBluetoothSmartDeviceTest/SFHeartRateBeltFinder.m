//
//  SFHeartRateBeltManager.m
//  SFHeartRateBelt
//
//  Created by Thomas Billicsich on 2014/01/28.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//

#import "SFHeartRateBeltFinder.h"

#define CBUUIDMake(string) [CBUUID UUIDWithString:string]

// Insert these to test if the BLE device really calls every method on the main thread, the internal
// ble-queue should not leak.
#define ASSERT_MAIN_THREAD NSAssert([[NSThread currentThread] isMainThread], @"Is not on main tread, but should be");




// Services
static NSString* kBleServiceBattery           = @"180F";
static NSString* kBleServiceHeartRate         = @"180D";
// Characteristics for BLE Service "Battery"
static NSString* kBleCharBatteryLevel         = @"2A19";
// Characteristics for BLE Service "Heart Rate"
static NSString* kBleCharHeartRateMeasurement = @"2A37";




@interface SFHeartRateBeltFinder ()
@property (readwrite) SInt8 batteryPercentageOfConnectedBelt;
@property (readwrite) SFBluetoothSmartDevice* heartRateBelt;
@end




@implementation SFHeartRateBeltFinder


CWL_SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(SFHeartRateBeltFinder, sharedHeartRateBeltManager);


- (id)init
{
  if (self = [super init]) {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:@"UIApplicationWillTerminateNotification" object:nil];
  }
  
  return self;
}


- (void)applicationWillTerminate:(NSNotification*)notification
{
  [self disconnect];
}




#pragma mark -
#pragma mark Public


- (void)startSearch
{
  // Ignore if already trying to connect
  if (self.heartRateBelt) {
    return;
  }
  
  // Create the dictionary that represents the services and characteristics that
  // you want to work with when connected to the BLE device
  NSDictionary* heartBeltServicesAndCharacteristics = @{
                                                        CBUUIDMake(kBleServiceHeartRate):
                                                          @[ CBUUIDMake(kBleCharHeartRateMeasurement) ],
                                                        
                                                        CBUUIDMake(kBleServiceBattery):
                                                          @[ CBUUIDMake(kBleCharBatteryLevel) ]
                                                        };
  
  // Only include the services the BLE device is expected to advertise
  NSArray* heartBeltAdvertisingServices = @[ CBUUIDMake(kBleServiceHeartRate) ];
  
  // Creating the BLE device automatically starts the scan of the CBCentralManager
  // Since we don't care about any specific belt, we just set the identifier to nil. Providing an NSUUID here
  // would only connect the heart rate belt object to that specific BLE device (Note: the NSUUID of the same
  // BLE device is different on every iOS device).
  self.heartRateBelt = [SFBluetoothSmartDevice withTheseServicesAndCharacteristics:heartBeltServicesAndCharacteristics
                                                                       advertising:heartBeltAdvertisingServices
                                                          andIdentifyingItselfWith:nil];
}


- (void)disconnect
{
  // When the BLE device is deallocated it will all BLE-operations concerned with it will be cancelled
  // automatically
  self.heartRateBelt = nil;
}




#pragma mark -
#pragma mark Private


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  ASSERT_MAIN_THREAD
  
  if ([keyPath isEqualToString:@"connected"]) {
    if (self.heartRateBelt.connected) {
      [self.delegate manager:self connectedToHeartRateBelt:self.heartRateBelt.identifier];
      [self.heartRateBelt subscribeToCharacteristic:CBUUIDMake(kBleCharHeartRateMeasurement)];
    }
    else {
      [self disconnectedFromBelt];
    }
  }
  else if ([keyPath isEqualToString:@"error"]) {
    NSLog(@"Registered error: %@", self.heartRateBelt.error.localizedDescription);
    self.heartRateBelt = nil;
    [self.delegate managerFailedToConnectToHRBelt:self];
  }
  else if ([keyPath isEqualToString:@"batteryLevel"]) {
    self.batteryPercentageOfConnectedBelt = self.heartRateBelt.batteryLevel;
  }
}


- (void)disconnectedFromBelt
{
  self.batteryPercentageOfConnectedBelt = -1;
}


- (void)setHeartRateBelt:(SFBluetoothSmartDevice *)heartRateBelt
{
  if (_heartRateBelt == heartRateBelt)
    return;
  
  [_heartRateBelt disconnect];
  _heartRateBelt.delegate = nil;
  [_heartRateBelt removeObserver:self forKeyPath:@"batteryLevel"];
  [_heartRateBelt removeObserver:self forKeyPath:@"connected"];
  [_heartRateBelt removeObserver:self forKeyPath:@"error"];
  
  _heartRateBelt = heartRateBelt;
  
  _heartRateBelt.delegate = self;
  [_heartRateBelt addObserver:self forKeyPath:@"batteryLevel" options:0 context:nil];
  [_heartRateBelt addObserver:self forKeyPath:@"connected" options:0 context:nil];
  [_heartRateBelt addObserver:self forKeyPath:@"error" options:0 context:nil];
}




#pragma mark -
#pragma mark SFBluetoothSmartDeviceDelegate


- (BOOL)shouldContinueSearch
{
  ASSERT_MAIN_THREAD
  
  return YES;
}


- (void)BTSmartDevice:(SFBluetoothSmartDevice*)device receivedData:(NSData*)data fromCharacteristic:(CBUUID*)uuid
{
  ASSERT_MAIN_THREAD
  
  if ([uuid isEqual:CBUUIDMake(kBleCharHeartRateMeasurement)]) {
    UInt8 heartRate;
    [data getBytes:&heartRate range:NSMakeRange(1, 1)];
    [self.delegate manager:self receivedHRUpdate:@(heartRate)];
  }
}


@end

#undef CBUUIDMake
