//
//  SFHeartRateBeltManager.h
//  SFHeartRateBelt
//
//  Created by Thomas Billicsich on 13.01.14.
//  Copyright (c) 2014 SimpliFlow. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CWLSynthesizeSingleton.h"

#import "SFBluetoothSmartDevice.h"




typedef NS_ENUM(NSInteger, SFHRError) {
  SFHRErrorNoBluetooth = 0,
  SFHRErrorNoDeviceFound,
  SFHRErrorUnableToDistinguishSingleDevice,
  SFHRErrorUnknown
};


@protocol SFHeartRateBeltManagerDelegate;




@interface SFHeartRateBeltManager : NSObject <SFBluetoothSmartDeviceDelegate, CBCentralManagerDelegate>

CWL_DECLARE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(SFHeartRateBeltManager, sharedHeartRateBeltManager)

@property (nonatomic, assign) id<SFHeartRateBeltManagerDelegate> delegate;

/// Is -1 if not connected to any belt. If connected to a belt this value
/// is updated every 5min.
@property (nonatomic, readonly) SInt8 batteryPercentageOfConnectedBelt;

/// Upon a successful connect the delegate is sent manager:connectedToHRBelt:.
/// If beltIdentifier is nil, then the search is conducted for timeout seconds and
/// the nearest belt will be connected to.
///
/// If the requested belt - or in the case of the beltIdentifier being nil, no
/// belt at all - has not been found within timeout seconds, if Bluetooth is not enabled
/// or if the manager failed to connect to the heart rate belt the delegate is sent
/// manager:failedToConnectToHRBelt:
///
/// If this message is sent while a connect is already in progress the call is ignored.
/// Providing a negative timeout defaults the timeout to 10s
///
/// One of the two following methods will be called.
///  * If the connect has been successful manager:connectedToHeartRateBelt: will be called
///  * If something happens during the connection process manager:failedToConnectWithError:  with an error containing a SFHRError code will be called (the class then seizes all activity until a further call to connectToHeartRateBelt:timeout:
///
/// after connect has been successful
///  * if an error is encountered, manager:disconnectedWithError: will be called with a describing error
///  * if disconnectFromHeartRateBelt is called, the response will also be manager:disconnectedWithError: but the error will be nil
//
- (void)connectToHeartRateBelt:(NSUUID*)beltIdentifier timeout:(NSTimeInterval)timeout;

/// Disconnects from a connected belt. Does nothing if no belt is connected. Aborts a possibly
/// running connect process.
- (void)disconnectFromHeartRateBelt;

@end




@protocol SFHeartRateBeltManagerDelegate
/// One of two possible responses to connectoToHeartRateBelt. Sent when connect
/// has been successful and HR-updates are expected to follow.
- (void)manager:(SFHeartRateBeltManager*)manager connectedToHeartRateBelt:(NSUUID*)beltIdentifier name:(NSString*)name;

/// One of two possible responses to connectoToHeartRateBelt. Sent when connect to belt failed.
/// Possible causes: belt already connected to other device, belt out of reach, no
/// bluetooth, belt undistinguishable from close by belt
- (void)manager:(SFHeartRateBeltManager*)manager failedToConnectWithError:(NSError*)error;

/// Necessary follow up to manager:connectedToHeartRateBelt:
- (void)manager:(SFHeartRateBeltManager*)manager disconnectedWithError:(NSError*)error;

/// Sent regularly (approx 1 to 2 Hz), after connect has been successful.
- (void)manager:(SFHeartRateBeltManager*)manager receivedHRUpdate:(NSNumber*)heartRate;
@optional
- (void)bluetoothAvailableAgain;
@end
