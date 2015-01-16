//
//  SFConsoleLogFormat.m
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-02-18.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.


#import "SFConsoleLogFormat.h"
#import <libkern/OSAtomic.h>




@implementation SFConsoleLogFormat


- (NSString *)stringFromDate:(NSDate *)date
{
  int32_t loggerCount = OSAtomicAdd32(0, &atomicLoggerCount);
  
  if (loggerCount <= 1)
  {
    // Single-threaded mode.
    
    if (threadUnsafeDateFormatter == nil)
    {
      threadUnsafeDateFormatter = [[NSDateFormatter alloc] init];
      [threadUnsafeDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
      [threadUnsafeDateFormatter setDateFormat:@"mm:ss.SSS"];
    }
    
    return [threadUnsafeDateFormatter stringFromDate:date];
  }
  else
  {
    // Multi-threaded mode.
    // NSDateFormatter is NOT thread-safe.
    
    NSString *key = @"MyCustomFormatter_NSDateFormatter";
    
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSDateFormatter *dateFormatter = [threadDictionary objectForKey:key];
    
    if (dateFormatter == nil)
    {
      dateFormatter = [[NSDateFormatter alloc] init];
      [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
      [dateFormatter setDateFormat:@"mm:ss.SSS"];
      
      [threadDictionary setObject:dateFormatter forKey:key];
    }
    
    return [dateFormatter stringFromDate:date];
  }
}


- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
  NSString *logLevel;
  switch (logMessage.flag)
  {
    case DDLogFlagError : logLevel = @"ERR"; break;
    case DDLogFlagWarning  : logLevel = @"WRN"; break;
    case DDLogFlagInfo  : logLevel = @"INF"; break;
    case DDLogFlagDebug : logLevel = @"DBG"; break;
    case DDLogFlagVerbose : logLevel = @"VRB"; break;
  }

  // for the record in case a simple file name is needed
  // NSString* simpleFilename = DDExtractFileNameWithoutExtension(logMessage->file, NO);
  
  NSString* dateString = [self stringFromDate:(logMessage.timestamp)];
  
  NSString* logString = [NSString stringWithFormat:@"%@ %@. %@", logLevel, dateString, logMessage.message];
  return logString;
}


- (void)didAddToLogger:(id <DDLogger>)logger
{
  OSAtomicIncrement32(&atomicLoggerCount);
}


- (void)willRemoveFromLogger:(id <DDLogger>)logger
{
  OSAtomicDecrement32(&atomicLoggerCount);
}


@end
