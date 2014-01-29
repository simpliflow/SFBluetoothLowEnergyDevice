//
//  SFViewController.m
//  SFBluetoothSmartDeviceTest
//
//  Created by Thomas Billicsich on 2014/01/28.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//

#import "SFViewController.h"
#import "Log4Cocoa.h"

@interface SFViewController ()

@end





@implementation SFViewController


+ (void)initialize
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    [[L4Logger rootLogger] setLevel:[L4Level info]];
    [[L4Logger rootLogger] addAppender: [[L4ConsoleAppender alloc] initTarget:YES withLayout: [L4Layout simpleLayout]]];
  });
}


- (void)viewDidLoad
{
  [super viewDidLoad];
  
  SFHeartRateBeltManager* hrManager = [SFHeartRateBeltManager sharedHeartRateBeltManager];
  hrManager.delegate = self;
  NSUUID* beltIdentifier = [[NSUUID alloc] initWithUUIDString:nil];
  [hrManager connectToHeartRateBelt:beltIdentifier timeout:10];
  [hrManager addObserver:self forKeyPath:@"batteryPercentageOfConnectedBelt" options:0 context:nil];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:@"batteryPercentageOfConnectedBelt"])
  {
    UInt8 batteryLevel = [SFHeartRateBeltManager sharedHeartRateBeltManager].batteryPercentageOfConnectedBelt;
    
    if (batteryLevel >= 0)
      self.batteryLevel.text = @(batteryLevel).stringValue;
    else
      self.batteryLevel.text = @"-";
  }
}


- (IBAction)disconnectButtonPushed:(UIButton*)sender
{
  SFHeartRateBeltManager* hrManager = [SFHeartRateBeltManager sharedHeartRateBeltManager];
  [hrManager disconnectFromHeartRateBelt];
  
  [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(connectToHRBelt) userInfo:nil repeats:NO];
}


- (void)connectToHRBelt
{
  SFHeartRateBeltManager* hrManager = [SFHeartRateBeltManager sharedHeartRateBeltManager];
  [hrManager connectToHeartRateBelt:nil timeout:10];
}




#pragma mark -
#pragma mark SFHeartRateBeltManagerDelegate


- (void)manager:(SFHeartRateBeltManager*)manager connectedToHeartRateBelt:(NSUUID*)beltIdentifier name:(NSString*)name
{
  log4Info(@"ViewCtrl: Connected.");
  self.heartRateBeltState.numberOfLines = 2;
  self.heartRateBeltState.text = [NSString stringWithFormat:@"Connected to\n%@", name];
  [self.heartRateBeltState sizeToFit];
}


- (void)manager:(SFHeartRateBeltManager*)manager failedToConnectWithError:(NSError*)error
{
  if (error.code == SFHRErrorNoBluetooth) {
    self.heartRateBeltState.numberOfLines = 1;
    self.heartRateBeltState.text = [NSString stringWithFormat:@"No Bluetooth"];
    [self.heartRateBeltState sizeToFit];
    return;
  }
  
  self.heartRateBeltState.numberOfLines = 2;
  self.heartRateBeltState.text = [NSString stringWithFormat:@"Failed\n%@", error.localizedDescription];
  [self.heartRateBeltState sizeToFit];
  
  SFHeartRateBeltManager* hrManager = [SFHeartRateBeltManager sharedHeartRateBeltManager];
  if (error.code == SFHRErrorNoDeviceFound) {
    log4Info(@"ViewCtrl: No device found. Retrying.");
    [hrManager connectToHeartRateBelt:nil timeout:10];
  }
  else {
    log4Info(@"ViewCtrl: Failed to connect. Error (%@): %@", error.domain, error.localizedDescription);
    [hrManager connectToHeartRateBelt:nil timeout:10];
  }
}


- (void)manager:(SFHeartRateBeltManager*)manager disconnectedWithError:(NSError*)error
{
  if (error.code == SFHRErrorNoBluetooth) {
    self.heartRateBeltState.numberOfLines = 1;
    self.heartRateBeltState.text = [NSString stringWithFormat:@"No Bluetooth"];
    [self.heartRateBeltState sizeToFit];
    return;
  }
  
  if (!error) {
    log4Info(@"ViewCtrl: Disconnected.");
    self.heartRateBeltState.numberOfLines = 1;
    self.heartRateBeltState.text = @"Disconnected";
  }
  else {
    log4Info(@"ViewCtrl: Disconnected. Error: %@", error.localizedDescription);
    self.heartRateBeltState.numberOfLines = 1;
    self.heartRateBeltState.text = [NSString stringWithFormat:@"Disconnected\n%@", error.localizedDescription];
  }
  [self.heartRateBeltState sizeToFit];

  SFHeartRateBeltManager* hrManager = [SFHeartRateBeltManager sharedHeartRateBeltManager];
  [hrManager connectToHeartRateBelt:nil timeout:10];
}


- (void)manager:(SFHeartRateBeltManager*)manager receivedHRUpdate:(NSNumber*)heartRate
{
  log4Info(@"ViewCtrl: HR update: %@", heartRate);
  self.heartRateLabel.text = heartRate.stringValue;
}


- (void)bluetoothAvailableAgain
{
  self.heartRateBeltState.numberOfLines = 1;
  self.heartRateBeltState.text = @"Searching";
  [self.heartRateBeltState sizeToFit];
  
  log4Info(@"ViewCtrl: Bluetooth available again");
  SFHeartRateBeltManager* hrManager = [SFHeartRateBeltManager sharedHeartRateBeltManager];
  [hrManager connectToHeartRateBelt:nil timeout:10];
}


@end
