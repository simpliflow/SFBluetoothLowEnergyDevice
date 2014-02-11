//
//  SFViewController.h
//  SFBluetoothSmartDeviceTest
//
//  Created by Thomas Billicsich on 2014/01/28.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "SFHeartRateBeltManager.h"


@interface SFViewController : UIViewController <SFHeartRateBeltManagerDelegate>

@property (weak, nonatomic) IBOutlet UILabel* heartRateLabel;
@property (weak, nonatomic) IBOutlet UILabel* heartRateBeltState;

@property (weak, nonatomic) IBOutlet UILabel* batteryLevel;

- (IBAction)disconnectButtonPushed:(UIButton*)sender;
@end
