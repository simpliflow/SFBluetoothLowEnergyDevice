//
//  SFHeartRateBeltManager.h
//  SFHeartRateBelt
//
//  Created by Thomas Billicsich on 2014/01/28.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CWLSynthesizeSingleton.h"

#import "SFBluetoothSmartDevice.h"



@protocol SFHeartRateBeltManagerDelegate;




@interface SFHeartRateBeltFinder : NSObject <SFBluetoothSmartDeviceDelegate>

CWL_DECLARE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(SFHeartRateBeltFinder, sharedHeartRateBeltManager)
@property (nonatomic, assign) id<SFHeartRateBeltManagerDelegate> delegate;

/// Is -1 if not connected to any belt. If connected to a belt this value
/// is updated every 5min.
@property (nonatomic, readonly) SInt8 batteryPercentageOfConnectedBelt;

/// If a heart rate belt is found the delegate is sent manager:connectedToHRBelt:,
/// heart rate updates will then start to come in.
- (void)startSearch;

/// Disconnects from a connected belt. Does nothing if no belt is connected. Aborts a possibly
/// running connect process.
- (void)disconnect;

@end




@protocol SFHeartRateBeltManagerDelegate

/// Possible response to connectToHeartRateBelt. Sent when connect has been successful and
/// HR-updates are expected to follow.
- (void)manager:(SFHeartRateBeltFinder*)manager connectedToHeartRateBelt:(NSUUID*)beltIdentifier;

/// Possible response to connectToHeartRateBelt. Sent when connect to belt failed. Possible causes:
/// belt already connected to other device, belt out of reach
- (void)managerFailedToConnectToHRBelt:(SFHeartRateBeltFinder*)manager;

/// Sent regularly (approx 1 to 2 Hz), after connect has been successful.
- (void)manager:(SFHeartRateBeltFinder*)manager receivedHRUpdate:(NSNumber*)heartRate;

@end