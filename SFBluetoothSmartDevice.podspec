Pod::Spec.new do |spec|
  spec.name         = 'SFBluetoothSmartDevice'
  spec.homepage     = 'https://github.com/simpliflow/SFBluetoothSmartDevice'
  spec.license      = 'COMMERCIAL'
  spec.version      = '0.0.1'
  spec.summary      = 'A CoreBluetooth wrapper for simple Bluetooth Smart (BLE) devices.'
  spec.platform     = :ios
  spec.ios.deployment_target  = '7.0'
  spec.authors      = 'Thomas Billicsich'
  spec.source_files     = 'SFBluetoothSmartDevice/Classes/*.{h,m}'
  spec.source     = { :git => 'https://github.com/simpliflow/SFBluetoothSmartDevice.git', :tag => 'v0.0.1' }
  spec.framework  = 'CoreBluetooth'
  spec.requires_arc = true

  spec.subspec 'Private' do |api_spec|
    api_spec.source_files = 'SFBluetoothSmartDevice/Classes/Private/*.{h,m}'
  end

end
