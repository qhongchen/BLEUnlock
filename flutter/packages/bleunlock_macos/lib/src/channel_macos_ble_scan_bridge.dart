import 'package:bleunlock_macos/src/macos_platform.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';
import 'package:flutter/services.dart';

class ChannelMacosBleScanBridge implements MacosBleScanBridge {
  ChannelMacosBleScanBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_macos/ble_scanner_methods'),
        _eventChannel = eventChannel ??
            const EventChannel('bleunlock_macos/ble_scanner_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Stream<Object?> get events => _eventChannel.receiveBroadcastStream();

  @override
  Future<Object?> refreshCapability() async {
    return _methodChannel.invokeMethod<Object?>('getScannerCapability');
  }

  @override
  Future<void> startScan() async {
    await _methodChannel.invokeMethod<void>('startScan');
  }

  @override
  Future<void> stopScan() async {
    await _methodChannel.invokeMethod<void>('stopScan');
  }
}
