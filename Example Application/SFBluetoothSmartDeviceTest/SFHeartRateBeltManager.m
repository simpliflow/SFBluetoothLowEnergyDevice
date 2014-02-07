//
//  SFHeartRateBeltManager.m
//  SFHeartRateBelt
//
//  Created by Thomas Billicsich on 2014/01/28.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//

#import "SFHeartRateBeltManager.h"

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






@interface SFHeartRateBeltManager ()
@property (nonatomic) SFBluetoothSmartDevice* heartRateBelt;
@property (nonatomic) NSTimeInterval timeout;
@property (nonatomic) NSTimer* findTimer;
@property (nonatomic) BOOL hrBeltHasBeenConnected;
@property (nonatomic) CBCentralManager* bluetoothStatusTracker;
@property (nonatomic) BOOL bluetoothDidBecomeNotAvailable;
@end


@implementation SFHeartRateBeltManager


CWL_SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(SFHeartRateBeltManager, sharedHeartRateBeltManager);


- (id)init
{
  if (self = [super init]) {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:@"UIApplicationWillTerminateNotification" object:nil];
    _bluetoothStatusTracker = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
  }
  return self;
}


- (void)applicationWillTerminate:(NSNotification*)notification
{
  [self disconnectFromHeartRateBelt];
}




#pragma mark -
#pragma mark Public Methods


- (void)connectToHeartRateBelt:(NSUUID*)beltIdentifier timeout:(NSTimeInterval)timeout;
{
  if (self.heartRateBelt) {
    [self.heartRateBelt linkWithIdentifier:beltIdentifier];
    return;
  }
  
  if (timeout > 0.0)
    self.timeout = timeout;
  else
    self.timeout = 0.0;
  
  self.hrBeltHasBeenConnected = NO;

  NSDictionary* heartBeltServicesAndCharacteristics = @{
                                                        CBUUIDMake(kBleServiceHeartRate) : @[CBUUIDMake(kBleCharHeartRateMeasurement)],
                                                        CBUUIDMake(kBleServiceBattery) : @[CBUUIDMake(kBleCharBatteryLevel)]
                                                        };
  NSArray* heartBeltAdvertisingServices = @[CBUUIDMake(kBleServiceHeartRate)];
  self.heartRateBelt = [SFBluetoothSmartDevice BTSmartDeviceWithServicesAndCharacteristics:heartBeltServicesAndCharacteristics
                                                                       advertising:heartBeltAdvertisingServices];
  [self.heartRateBelt linkWithIdentifier:beltIdentifier];
  if (self.timeout)
    self.findTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeout target:self selector:@selector(findTimedOut:) userInfo:nil repeats:NO];
}


- (SInt8)batteryPercentageOfConnectedBelt
{
//  if (self.heartRateBelt.linked)
//    return self.heartRateBelt.batteryLevel;
//  else
    return -1;
}


- (void)disconnectFromHeartRateBelt
{
  [self.heartRateBelt unlink];
}




#pragma mark Private Methods


- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:@"batteryLevel"]) {
    [self willChangeValueForKey:@"batteryPercentageOfConnectedBelt"];
    [self didChangeValueForKey:@"batteryPercentageOfConnectedBelt"];
  }
}


// This method is only called if the specific belt (or no belt at all if specificHRBelt is nil)
// has been found within the timeout time span.
- (void)findTimedOut:(NSTimer*)timer
{
  NSLog(@"HR-Mgr: Search for belt timed out.");
  
  [self.heartRateBelt unlink];
  [self.delegate manager:self failedToConnectWithError:[self error:SFHRErrorNoDeviceFound]];
}


- (void)setHeartRateBelt:(SFBluetoothSmartDevice *)heartRateBelt
{
  if (_heartRateBelt == heartRateBelt)
    return;
  
  [_heartRateBelt unlink];
  _heartRateBelt.delegate = nil;
  [_heartRateBelt removeObserver:self forKeyPath:@"batteryLevel"];
  
  _heartRateBelt = heartRateBelt;
  
  _heartRateBelt.delegate = self;
  [_heartRateBelt addObserver:self forKeyPath:@"batteryLevel" options:0 context:nil];
}


- (NSError*)error:(SFHRError)errorCode
{
  return [NSError errorWithDomain:@"SFHRError"
                             code:errorCode
                         userInfo:@{
                                    NSLocalizedDescriptionKey: @"Error happened"
                                    }];
}




#pragma mark SFBluetoothSmartDeviceDelegate


- (void)BTSmartDeviceConnectedSuccessfully:(SFBluetoothSmartDevice*)device
{
  NSLog(@"HR-Mgr: device connected successfully");
  [self.findTimer invalidate];
  self.findTimer = nil;
  self.hrBeltHasBeenConnected = YES;
  SFBluetoothSmartDevice* hrBelt = self.heartRateBelt;
  [self.delegate manager:self connectedToHeartRateBelt:hrBelt.identifier name:hrBelt.name];
  [hrBelt subscribeToCharacteristic:CBUUIDMake(kBleCharHeartRateMeasurement)];
}


- (void)BTSmartDevice:(SFBluetoothSmartDevice*)device receivedData:(NSData*)data fromCharacteristic:(CBUUID*)uuid
{
  if ([uuid isEqual:CBUUIDMake(kBleCharHeartRateMeasurement)]) {
    UInt8 heartRate;
    [data getBytes:&heartRate range:NSMakeRange(1, 1)];
    [self.delegate manager:self receivedHRUpdate:@(heartRate)];
  }
}


- (void)BTSmartDeviceEncounteredError:(NSError*)error
{
  NSLog(@"HR-Mgr: bt-device reported error (%@ %d: %@)", error.domain, error.code, error.localizedDescription);
  NSError* hrError = nil;
  BOOL abortFind = YES;
  switch (error.code) {
    case SFBluetoothSmartErrorUnableToDistinguishClosestDevice:
      hrError = [self error:SFHRErrorUnableToDistinguishSingleDevice];
      break;
    case SFBluetoothSmartErrorProblemsInConnectionProcess:
      hrError = [self error:SFHRErrorUnknown];
      abortFind = NO;
      break;
    case SFBluetoothSmartErrorProblemsInDiscoveryProcess:
      hrError = [self error:SFHRErrorUnknown];
      abortFind = NO;
      break;
    case SFBluetoothSmartErrorConnectionClosedByDevice:
      hrError = [self error:SFHRErrorUnknown];
      break;
    case SFBluetoothSmartErrorUnknown:
      hrError = [self error:SFHRErrorUnknown];
      abortFind = NO;
      break;
  }
  
  if (abortFind) {
    [self.findTimer invalidate];
    self.findTimer = nil;
    [self.heartRateBelt unlink];
    if (self.hrBeltHasBeenConnected) {
      [self.delegate manager:self disconnectedWithError:hrError];
      self.hrBeltHasBeenConnected = NO;
    }
    else {
      [self.delegate manager:self failedToConnectWithError:hrError];
    }
  }
}


- (void)noBluetooth
{
  NSLog(@"HR-Mgr: no Bluetooth");
  [self.findTimer invalidate];
  self.findTimer = nil;
  self.bluetoothDidBecomeNotAvailable = YES;
  
  [self.heartRateBelt unlink];
  if (self.hrBeltHasBeenConnected) {
    [self.delegate manager:self disconnectedWithError:[self error:SFHRErrorNoBluetooth]];
  }
  else {
    [self.delegate manager:self failedToConnectWithError:[self error:SFHRErrorNoBluetooth]];
  }
}


// has no effect, since on bluetooth going not available the bluetooth device is deallocated! (there
// fore the own cbcentralmanager)
- (void)fixedNoBluetooth
{
  NSLog(@"HR-Mgr: Bluetooth available again. This should not be called!!");
  [self.delegate bluetoothAvailableAgain];
}




#pragma mark -
#pragma mark CBCentralManagerDelegate


- (void)centralManagerDidUpdateState:(CBCentralManager*)central
{
  if (central.state == CBCentralManagerStatePoweredOn && self.bluetoothDidBecomeNotAvailable) {
    self.bluetoothDidBecomeNotAvailable = NO;
    [self.delegate bluetoothAvailableAgain];
  }
}



@end

#undef DISPATCH_ON_MAIN_QUEUE
#undef CBUUIDMake
