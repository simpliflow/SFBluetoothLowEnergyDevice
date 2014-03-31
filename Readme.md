# SFBluetoothLowEnergyDevice, Beta
An opinionated wrapper for CoreBluetooth to ease the communication with simple Bluetooth Low Energy (Bluetooth smart, Bluetooth 4.0, BLE) devices.

It assumes that you know the service and characteristic UUIDs of the device you want to communicate with and which of these services are advertised. All BLE actions (scanning, connecting, discovering, writing, reading) are handled on a separate queue, all delegate callbacks are returned on the main queue.


## Getting started (by example of a heart rate belt)
1. create an SFBLEDeviceManager by providing the creation method with a dictionary containing the service UUIDs-Strings as keys and the characteristic UUIDs-Strings in an array set as values for those keys.

        NSString* BLEServiceHeartRate         = @"180D";
        NSString* BLECharHeartRateMeasurement = @"2A37";
	      NSDictionary* HRServsAndCharacs = @{
                                  BLEServiceHeartRate :    @[BLECharHeartRateMeasurement]
                                             };
        SFBLEDeviceManager* deviceManager = [SFBLEDeviceManager managerForDevicesWithServicesAndCharacteristics:HRServsAndCharacs advertising:@[BLEServiceHeartRate]];
        deviceManager.delegate = self;

2. Start scanning for any device (or for a device with a specific identifier)

        [deviceManager scanFor:nil timeout:3.0];

3. The delegate callback `managerFoundDevices:` will send you all found devices. Take one and link to it.

        - (void)managerFoundDevices:(NSArray*)bleDevices {
          SFBLEDevice* heartRateBelt = bleDevices.firstObject;
          heartRateBelt.delegate = self;
          [heartRateBelt link];
        }

4. The device will now connect to the peripheral and discover all services and characteristics that you specified. Upon success, `deviceLinkedSuccessfully:` will be called on your device's delegate. You could then e.g. subscribe to updates to a characteristic.

        - (void)deviceLinkedSuccessfully:(SFBLEDevice*)device {
          [device subscribeToCharacteristic:BLECharHeartRateMeasurement];
        }

5. Updates will then be delivered to your device's delegate via `device:receivedData:fromCharacteristic:`.

6. To cut the connection to the peripheral call `unlink`.

        [device unlink];


## Purpose and Intention
CoreBluetooth is quite complicated if you want to communicate with a simple BLE device – a heart rate belt for example. To connect to the device SFBluetoothSmartDevice only requires you to define a dictionary with the UUIDs of the services and characteristics you are searching for. Discovery of the peripheral, connecting to it, and discovering of services and characteristics is handled by the Pod.

The Pod has a limited reporting of errors that happen during the search-connect process as there is usually only the recovery option of restarting the BLE device.


## Limitations
Due to its simplified nature the wrapper does not allow for:
* usage of the same characteristic in more than one service of interest (i.e. if you had a device that would offer the services "Health Thermometer" and "Environment Temperature" both including the characteristic `org.bluetooth.characteristic.temperature_measurement`, you could only include one of the two services since the wrapper does not allow for a distinction between characteristics according to the service they are included in).
* multiple instances of the same device are not supported –  same refers to the array of advertised services. Also, you will not be able to create two instances to work with different parts of the same physical BLE device (but that is a limitation of CoreBluetooth as well and not intended by the Bluetooth specification either).
