import 'package:bleunlock_windows/src/windows_platform.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';
import 'package:flutter/services.dart';

class ChannelWindowsBleScanBridge implements WindowsBleScanBridge {
  ChannelWindowsBleScanBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_windows/ble_scanner_methods'),
        _eventChannel = eventChannel ??
            const EventChannel('bleunlock_windows/ble_scanner_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Stream<Object?> get events => _eventChannel.receiveBroadcastStream();

  @override
  Future<Object?> refreshCapability() async {
    return _methodChannel.invokeMethod<Object?>('getScannerCapability');
  }

  @override
  Future<void> startScan({BleScanMode mode = BleScanMode.passive}) async {
    await _methodChannel.invokeMethod<void>(
      'startScan',
      {'mode': mode.name},
    );
  }

  @override
  Future<void> stopScan() async {
    await _methodChannel.invokeMethod<void>('stopScan');
  }
}
