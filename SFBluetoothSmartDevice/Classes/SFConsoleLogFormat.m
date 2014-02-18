//
//  SFConsoleLogFormat.m
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-02-18.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.


#import "SFConsoleLogFormat.h"




@implementation SFConsoleLogFormat


static   NSDateFormatter* __formatter;
+ (void)initialize
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{

    __formatter = [[NSDateFormatter alloc] init];
    __formatter.dateFormat = @"mm:ss.SSS";
  });
}




- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
  NSString *logLevel;
  switch (logMessage->logFlag)
  {
    case LOG_FLAG_ERROR : logLevel = @"ERR"; break;
    case LOG_FLAG_WARN  : logLevel = @"WRN"; break;
    case LOG_FLAG_INFO  : logLevel = @"INF"; break;
    case LOG_FLAG_DEBUG : logLevel = @"DBG"; break;
    default             : logLevel = @"VRB"; break;
  }

  // for the record, in case a simple file name is needed
  // NSString* simpleFilename = DDExtractFileNameWithoutExtension(logMessage->file, NO);
  
  NSString* logString = [NSString stringWithFormat:@"%@ %@. %@", logLevel,  [__formatter stringFromDate:logMessage->timestamp], logMessage->logMsg];
  return logString;
}


@end
