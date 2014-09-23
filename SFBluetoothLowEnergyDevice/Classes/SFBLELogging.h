//
//  SFBLELogging.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-04-04.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import <CocoaLumberjack/CocoaLumberjack.h>


// To define a different local (per file) log level
// put the following line _before_ the import of SFBLELogging.h
//  #define LOCAL_LOG_LEVEL LOG_LEVEL_DEBUG
#define GLOBAL_LOG_LEVEL LOG_LEVEL_DEBUG
#ifndef LOCAL_LOG_LEVEL
  #define LOCAL_LOG_LEVEL GLOBAL_LOG_LEVEL
#endif

static int ddLogLevel = LOCAL_LOG_LEVEL;
