# SFBluetoothLowEnergyDevice, Beta
A wrapper for CoreBluetooth easy interaction with simple Bluetooth Low Energy (Bluetooth smart, Bluetooth 4.0, BLE) devices.

 All BLE actions (scanning, connecting, discovering, writing, reading) are handled on a background queue, you work on the main thread, without worrying about concurrency.
It assumes that you know the service and characteristic UUIDs of the device you want to communicate with and which of these services are advertised. If you include the battery service and characteristic, the pod takes care of regular updates.

## Getting started (by example of a heart rate belt)
1. create an SFBLEDeviceFinder by providing the creation method with a dictionary containing the service UUIDs-Strings as keys and the characteristic UUIDs-Strings in an array set as values for those keys.

```objc
CBUUID* BLEServiceHeartRate         = [CBUUID UUIDWithString:@"180D"];
CBUUID* BLECharHeartRateMeasurement = [CBUUID UUIDWithString:@"2A37"];
NSDictionary* HRServsAndCharacs = @{
                          BLEServiceHeartRate :    @[BLECharHeartRateMeasurement]
                                     };
SFBLEDeviceManager* finder = [SFBLEDeviceFinder managerForDevicesWithServicesAndCharacteristics:HRServsAndCharacs advertising:@[BLEServiceHeartRate]];
finder.delegate = self;
```

2. Start scanning for any device

```objc
[finder findDevices:3.0];
```

3. The delegate callback `managerFoundDevices:` will send you all found devices. Take one and link to it.

```objc
- (void)finderFoundDevices:(NSArray*)bleDevices error:(NSError*)error {
  if (bleDevices.count) {
    SFBLEDevice* heartRateBelt = bleDevices.firstObject;
    heartRateBelt.delegate = self;
    [heartRateBelt link];
  }
}
```

4. The device will connect itself to the peripheral and discover all services and characteristics that you specified. Upon success, `deviceLinkedSuccessfully:` will be called on your device's delegate. You could then e.g. subscribe to updates to a characteristic.

```objc
- (void)deviceLinkedSuccessfully:(SFBLEDevice*)device {
  [device subscribeToCharacteristic:BLECharHeartRateMeasurement];
}
```

5. Updates will then be delivered to your device's delegate via `device:receivedData:fromCharacteristic:`.

6. To cut the connection to the peripheral call `unlink`.

```objc
[device unlink];
```


## Purpose and Intention
CoreBluetooth is quite complicated if you want to communicate with a simple BLE device – a heart rate belt for example. To connect to the device SFBluetoothSmartDevice only requires you to define a dictionary with the UUIDs of the services and characteristics you are searching for. Discovery of the peripheral, connecting to it, and discovering of services and characteristics is handled by the Pod.

The Pod has a limited reporting of errors that happen during the search-connect process as there is usually only the recovery option of restarting the BLE device.


## Limitations
Due to its simplified nature the wrapper does not allow for:
* usage of the same characteristic in more than one service of interest (i.e. if you had a device that would offer the services "Health Thermometer" and "Environment Temperature" both including the characteristic `org.bluetooth.characteristic.temperature_measurement`, you could only include one of the two services since the wrapper does not allow for a distinction between characteristics according to the service they are included in).
* multiple SFBLEDevice instances for the same physical BLE device are not supported.


## Questions
**Why is it called __linking__ and not connecting?**

To be able to interact with the device you need to do more than connecting, in the sense that the word _connect_ is used in the CoreBluetooth framework. You also need to discover the services and characteristics, which is all handled by the pod for you, and to express this I thought _linking_ would be more approriate than _connecting_.
