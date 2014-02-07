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
  [hrManager connectToHeartRateBelt:nil timeout:0];
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


- (void)manager:(SFHeartRateBeltFinder*)manager connectedToHeartRateBelt:(NSUUID*)beltIdentifier name:(NSString*)name
{
  NSLog(@"ViewCtrl: Connected.");
  self.heartRateBeltState.numberOfLines = 2;
  self.heartRateBeltState.text = [NSString stringWithFormat:@"Connected to\n%@", name];
  [self.heartRateBeltState sizeToFit];
}


- (void)manager:(SFHeartRateBeltFinder*)manager failedToConnectWithError:(NSError*)error
{
  if (error.code == SFHRErrorNoBluetooth) {
    self.heartRateBeltState.numberOfLines = 1;
    self.heartRateBeltState.text = [NSString stringWithFormat:@"No Bluetooth"];
    [self.heartRateBeltState sizeToFit];
    return;
  }
  
  NSLog(@"ViewCtrl: Failed to connect. Error: %@", error.localizedDescription);
  
  self.heartRateBeltState.numberOfLines = 2;
  self.heartRateBeltState.text = [NSString stringWithFormat:@"Failed\n%@", error.localizedDescription];
  [self.heartRateBeltState sizeToFit];
  
  SFHeartRateBeltFinder* hrManager = [SFHeartRateBeltFinder sharedHeartRateBeltManager];
  [hrManager connectToHeartRateBelt:nil timeout:0];
}


- (void)manager:(SFHeartRateBeltFinder*)manager disconnectedWithError:(NSError*)error
{
  if (error.code == SFHRErrorNoBluetooth) {
    self.heartRateBeltState.numberOfLines = 1;
    self.heartRateBeltState.text = [NSString stringWithFormat:@"No Bluetooth"];
    [self.heartRateBeltState sizeToFit];
    return;
  }
  
  if (!error) {
    NSLog(@"ViewCtrl: Disconnected.");
    self.heartRateBeltState.numberOfLines = 1;
    self.heartRateBeltState.text = @"Disconnected";
  }
  else {
    NSLog(@"ViewCtrl: Disconnected. Error: %@", error.localizedDescription);
    self.heartRateBeltState.numberOfLines = 1;
    self.heartRateBeltState.text = [NSString stringWithFormat:@"Disconnected\n%@", error.localizedDescription];
  }
  [self.heartRateBeltState sizeToFit];

  SFHeartRateBeltFinder* hrManager = [SFHeartRateBeltFinder sharedHeartRateBeltManager];
  [hrManager connectToHeartRateBelt:nil timeout:0];
}


- (void)manager:(SFHeartRateBeltFinder*)manager receivedHRUpdate:(NSNumber*)heartRate
{
  NSLog(@"ViewCtrl: HR update: %@", heartRate);
  self.heartRateLabel.text = heartRate.stringValue;
}


- (void)bluetoothAvailableAgain
{
  self.heartRateBeltState.numberOfLines = 1;
  self.heartRateBeltState.text = @"Searching";
  [self.heartRateBeltState sizeToFit];
  
  NSLog(@"ViewCtrl: Bluetooth available again");
  SFHeartRateBeltFinder* hrManager = [SFHeartRateBeltFinder sharedHeartRateBeltManager];
  [hrManager connectToHeartRateBelt:nil timeout:0];
}


@end
