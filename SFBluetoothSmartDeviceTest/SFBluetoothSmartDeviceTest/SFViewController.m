//
//  SFViewController.m
//  SFBluetoothSmartDeviceTest
//
//  Created by Thomas Billicsich on 2014/01/28.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//

#import "SFViewController.h"
#import "SFHeartRateBeltFinder.h"


@interface SFViewController ()

@end





@implementation SFViewController


- (void)viewDidLoad
{
  [super viewDidLoad];
  
  SFHeartRateBeltFinder* hrManager = [SFHeartRateBeltFinder sharedHeartRateBeltManager];
  hrManager.delegate = self;
  [hrManager startSearch];
  [hrManager addObserver:self forKeyPath:@"batteryPercentageOfConnectedBelt" options:0 context:nil];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:@"batteryPercentageOfConnectedBelt"])
  {
    UInt8 batteryLevel = [SFHeartRateBeltFinder sharedHeartRateBeltManager].batteryPercentageOfConnectedBelt;
    
    if (batteryLevel >= 0)
      self.batteryLevel.text = @(batteryLevel).stringValue;
    else
      self.batteryLevel.text = @"-";
  }
}




#pragma mark -
#pragma mark SFHeartRateBeltManagerDelegate


- (void)manager:(SFHeartRateBeltFinder*)manager connectedToHeartRateBelt:(NSUUID*)beltIdentifier
{
  self.heartRateBeltState.text = @"Connected";
}


- (void)managerFailedToConnectToHRBelt:(SFHeartRateBeltFinder*)manager
{
  self.heartRateBeltState.text = @"Disconnected";
  [manager startSearch];
}


- (void)manager:(SFHeartRateBeltFinder*)manager receivedHRUpdate:(NSNumber*)heartRate
{
  self.heartRateLabel.text = heartRate.stringValue;
}


@end
