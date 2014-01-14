//
//  SFBluetoothSmartDeviceManager.h
//  SFBluetoothSmartDevice
//
//  Created by Thomas Billicsich on 14.01.14.
//  Copyright (c) 2014 SimpliFlow. All rights reserved.




#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>




@protocol SFBluetoothSmartDeviceManagerDelegate;




@interface SFBluetoothSmartDeviceManager : NSObject <CBCentralManagerDelegate>

+ (instancetype)deviceManager;

@property (nonatomic) NSTimeInterval timeout;

- (void)find:(NSUUID*)identifier advertising:(NSArray*)services for:(id<SFBluetoothSmartDeviceManagerDelegate>)delegate;
- (void)cancelPeripheralConnection:(CBPeripheral*)peripheral;
@end




@protocol SFBluetoothSmartDeviceManagerDelegate
- (void)manager:(SFBluetoothSmartDeviceManager*)manager connectedToSuitablePeripheral:(CBPeripheral*)peripheral;
- (void)managerFailedToConnectToSuitablePeripheral:(SFBluetoothSmartDeviceManager*)manager;
- (void)manager:(SFBluetoothSmartDeviceManager*)manager disconnectedFromPeripheral:(CBPeripheral*)peripheral;
@end
