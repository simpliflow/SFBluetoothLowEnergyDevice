//
//  SFViewController.h
//  SFBLEDeviceExample
//
//  Created by Thomas Billicsich on 2014-04-07.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import <UIKit/UIKit.h>
#import "SFBLEDeviceFinder.h"
#import "SFBLEDevice.h"




@interface SFViewController : UIViewController <SFBLEDeviceDelegate, SFBLEDeviceFinderDelegate>

- (IBAction)startFind:(id)sender;
- (IBAction)disconnect:(id)sender;

@end
