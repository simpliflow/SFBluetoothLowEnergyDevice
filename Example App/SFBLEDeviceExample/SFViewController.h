//
//  SFViewController.h
//  SFBLEDeviceExample
//
//  Created by Thomas Billicsich on 2014-04-07.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import <UIKit/UIKit.h>
#import "SFBLEDeviceFinder.h"
#import "SFBLEDevice.h"




extern NSString* const BLEServiceHeartRate;
extern NSString* const BLECharHeartRateMeasurement;




@interface SFViewController : UIViewController <SFBLEDeviceDelegate, SFBLEDeviceFinderDelegate>

@property (weak, nonatomic) IBOutlet UILabel* stateLabel;
@property (weak, nonatomic) IBOutlet UILabel* hrLabel;

- (IBAction)startFind:(id)sender;
- (IBAction)link:(id)sender;
- (IBAction)unlink:(id)sender;

@end
