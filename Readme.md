# SFBluetoothSmartDevice, Alpha
**Note: the information in this Readme is outdated as of Release 0.5.0**
An opinionated wrapper for CoreBluetooth to ease the communication with simple Bluetooth smart (Bluetooth Low Energy, Bluetooth 4.0, BLE) devices.

## Purpose and Intention
CoreBluetooth is quite complicated if you want to communicate with a simple BLE device – a heart rate belt for example. To connect to the device SFBluetoothSmartDevice only requires you to define a dictionary with the UUIDs of the services and characteristics you are searching for. Discovery of the peripheral, service, characteristics and connecting is handled for you.

The Pod has a limited reporting of errors that happen during the search-connect process as there is usually only the recovery option of restarting the BLE device. Errors that can be dealt with in code will be handled for you too, mostly by restarting the connection process.

As long as an instance of SFBluetoothSmartDevice exists it is assumed that you want to connect to such a device. Only when the instance is deallocated, the search process is halted.

## Limitations
Due to its simplified nature the wrapper does not allow for:
* usage of the same characteristic in more than one service of interest (i.e. if you had a device that would offer the services "Health Thermometer" and "Environment Temperature" both including the characteristic `org.bluetooth.characteristic.temperature_measurement`, you could only include one of the two services since the wrapper does not allow for a distinction between characteristics according to the service they are included in).
* multiple instances of the same device are not supported –  same refers to the array of advertised services. Also, you will not be able to create two instances to work with different parts of the same physical BLE device (but that is a limitation of CoreBluetooth as well and not intended by the Bluetooth specification either).