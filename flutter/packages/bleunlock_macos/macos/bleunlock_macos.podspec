Pod::Spec.new do |s|
  s.name             = 'bleunlock_macos'
  s.version          = '0.1.0'
  s.summary          = 'macOS platform implementation for BLEUnlock.'
  s.description      = <<-DESC
macOS platform bridge for BLEUnlock, including passive CoreBluetooth scanning.
                       DESC
  s.homepage         = 'https://github.com/skyearn/BLEUnlock'
  s.license          = { :type => 'MIT' }
  s.author           = { 'BLEUnlock' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.info_plist = {
    'NSBluetoothAlwaysUsageDescription' => 'BLEUnlock uses Bluetooth to detect nearby devices for proximity-based lock and unlock decisions.',
    'NSBluetoothPeripheralUsageDescription' => 'BLEUnlock uses Bluetooth to detect nearby devices for proximity-based lock and unlock decisions.'
  }
  s.resource_bundles = {
    'bleunlock_macos_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -framework login -lsqlite3',
    'SYSTEM_FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(SYSTEM_LIBRARY_DIR)/PrivateFrameworks'
  }
end
