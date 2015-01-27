# SFBluetoothLowEnergyDevice

## Version 0.10.3
* Updated to CocoaLumberjack 2-RC

## Version 0.10.0
* First public release
* Added example app to find and connect to heart rate belts

## Version 0.9.4
* Reduced log level to INFO

## Version 0.9.3
* Refinements: logs, comments, file placement in pod and private subpod

## Version 0.9.2
* Fixed error in error code (bad day)

## Version 0.9.1
* Fixed error in error assignment – seriously :)

## Version 0.9.0
* Not finding a specific device no longer must return an empty array (it contains all devices that have been found)

## Version 0.8.0
* Refactored: Manager is now Finder

## Version 0.7.1
* Error domain is string constant `kSFBluetoothLowEnergyErrorDomain`

## Version 0.7.0
* Not finding a specific device does not longer return an error, just an emtpy array
* Specific device can be found by identifier or name
* Renamed pod from SFBluetoothSmartDevice to SFBluetoothLowEnergyDevice

## Version 0.6.0
* Not finding a device does no longer return an error, just an empty array
* Small improvements: residue code, code arrangement, concurrency

## Version 0.5.4
* Improved handling of unavailable Bluetooth

## Version 0.5.3
* Made the custom formatter thread safe with information and code from Luberjack Github-Wiki
* Moved files that are not meant to be accessed from outside to the private directory

## Version 0.5.2
* Changed to logging framework to _Lumberjack_ due to crash problems in some apps

## Version 0.5.1
* Reduced log level to info

## Version 0.5.0
* Complete rewrite, architecture is again splitted into a manager and devices.

## Version 0.0.1
* Initial Release
