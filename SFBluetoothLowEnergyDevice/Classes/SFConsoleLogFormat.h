//
//  SFConsoleLogFormat.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-02-18.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.
//
//
//  The thread safe code is taken from
//  https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/CustomFormatters (v2013-11-11)


#import <Foundation/Foundation.h>
#import <CocoaLumberjack/CocoaLumberjack.h>




@interface SFConsoleLogFormat : NSObject <DDLogFormatter> {
  int atomicLoggerCount;
  NSDateFormatter* threadUnsafeDateFormatter;
}


@end
