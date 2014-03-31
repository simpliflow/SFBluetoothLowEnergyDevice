Pod::Spec.new do |spec|
  spec.name         = 'SFBluetoothLowEnergyDevice'
  spec.homepage     = 'https://github.com/simpliflow/SFBluetoothLowEnergyDevice'
  spec.license      = 'COMMERCIAL'
  spec.version      = '0.7.0'
  spec.summary      = 'A CoreBluetooth wrapper for simple Bluetooth low energy (also known as: Bluetooth 4.0, Bluetooth Smart, BLE) devices.'
  spec.platform     = :ios
  spec.ios.deployment_target  = '7.0'
  spec.authors      = 'Thomas Billicsich'
  spec.source_files     = 'SFBluetoothLowEnergyDevice/Classes/*.{h,m}'
  spec.source     = { :git => 'https://github.com/simpliflow/SFBluetoothLowEnergyDevice.git', :tag => 'v0.7.0' }
  spec.dependency  'CocoaLumberjack'
  spec.framework  = 'CoreBluetooth'
  spec.requires_arc = true

  spec.subspec 'Private' do |api_spec|
    api_spec.source_files = 'SFBluetoothLowEnergyDevice/Classes/Private/*.{h,m}'
  end

end
