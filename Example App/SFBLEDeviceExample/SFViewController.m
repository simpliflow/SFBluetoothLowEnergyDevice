//
//  SFViewController.m
//  SFBLEDeviceExample
//
//  Created by Thomas Billicsich on 2014-04-07.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import "SFViewController.h"



@interface SFViewController ()
@property (nonatomic) SFBLEDeviceFinder* finder;
@property (nonatomic) SFBLEDevice* device;
@end




@implementation SFViewController


- (void)viewDidLoad
{
  [super viewDidLoad];
  
  
  self.finder = [SFBLEDeviceFinder finderForDevicesWithServicesAndCharacteristics:nil advertising:nil];
}


- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
}




#pragma mark -
#pragma mark User Interaction


- (IBAction)startFind:(id)sender
{
  [self.finder findDevices:5];
}


- (IBAction)disconnect:(id)sender
{
  
}




#pragma mark -
#pragma mark SFBLEDeviceFinderDelegate


- (void)finderFoundDevices:(NSArray*)bleDevices error:(NSError*)error
{
  if (bleDevices.count) {
    self.device = bleDevices.firstObject;
  }
}


- (void)finderStoppedFindWithError:(NSError*)error
{

}


- (void)bluetoothNotAvailable
{

}


- (void)bluetoothAvailableAgain
{

}




#pragma mark -
#pragma mark SFBLEDeviceDelegate


- (void)deviceLinkedSuccessfully:(SFBLEDevice*)device
{

}


- (void)device:(SFBLEDevice*)SFBLEDevice failedToLink:(NSError*)error
{

}


- (void)device:(SFBLEDevice*)SFBLEDevice unlinked:(NSError*)error
{

}


- (void)device:(SFBLEDevice*)device receivedData:(NSData*)data fromCharacteristic:(CBUUID*)uuid
{

}


@end
