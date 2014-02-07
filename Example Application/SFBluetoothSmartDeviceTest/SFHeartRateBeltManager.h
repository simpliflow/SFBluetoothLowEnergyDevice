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




@interface SFHeartRateBeltManager : NSObject <SFBluetoothSmartDeviceDelegate>

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
/// * if this message is sent while a connect is already in progress the call is ignored.
/// * Providing a negative timeout defaults to no timeout
/// * following a call to this method one of the two following methods will be called:
///  - if the connect has been successful manager:connectedToHeartRateBelt:
///  - if something happens during the connection process manager:failedToConnectWithError:
///    with an error containing a SFHRError code (the class then seizes all activity until
///    a further call to connectToHeartRateBelt:timeout:
- (void)connectToHeartRateBelt:(NSUUID*)beltIdentifier timeout:(NSTimeInterval)timeout;

/// Disconnects from a connected belt. Does nothing if no belt is connected. Aborts a possibly
/// running connect process.
- (void)disconnectFromHeartRateBelt;

@end




@protocol SFHeartRateBeltManagerDelegate
/// One of two possible responses to connectToHeartRateBelt. Sent when connect
/// has been successful and HR-updates are expected to follow.
/// If the delegate has been sent this method, the connection is up and running and updates
/// via manager:receivedHRUpdate: can be expected until:
///  * an error is encountered, then manager:disconnectedWithError: with a describing SFHRError
///      will be called
///  * disconnectFromHeartRateBelt is called, then the response will also be
///      manager:disconnectedWithError: but the error will be nil
- (void)manager:(SFHeartRateBeltManager*)manager connectedToHeartRateBelt:(NSUUID*)beltIdentifier name:(NSString*)name;

/// One of two possible responses to connectoToHeartRateBelt. Sent when connect to belt failed.
/// Possible causes: no belt found within timeout, no bluetooth, belt undistinguishable
/// from other nearby belt
/// In case of no Bluetooth you should not send connectToHeartRateBelt:timeout: until Bluetooth
/// is back on, which is communicated to you via bluetoothAvailableAgain
- (void)manager:(SFHeartRateBeltManager*)manager failedToConnectWithError:(NSError*)error;

/// Necessary follow up to manager:connectedToHeartRateBelt:
- (void)manager:(SFHeartRateBeltManager*)manager disconnectedWithError:(NSError*)error;

/// Sent regularly (approx 1 to 2 Hz), after connect has been successful.
- (void)manager:(SFHeartRateBeltManager*)manager receivedHRUpdate:(NSNumber*)heartRate;

@optional
/// This method is called everytime Bluetooth comes back on. It is not called at app start, if BT
/// is already on.
- (void)bluetoothAvailableAgain;
@end
