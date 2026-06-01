import 'package:bleunlock_macos/src/macos_platform.dart';
import 'package:flutter/services.dart';

class ChannelMacosSessionBridge implements MacosSessionBridge {
  ChannelMacosSessionBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_macos/session_methods'),
        _eventChannel = eventChannel ??
            const EventChannel('bleunlock_macos/session_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Stream<Object?> get events => _eventChannel.receiveBroadcastStream();

  @override
  Future<bool> isLocked() async {
    return await _methodChannel.invokeMethod<bool>('isLocked') ?? false;
  }

  @override
  Future<void> lock() async {
    await _methodChannel.invokeMethod<void>('lock');
  }

  @override
  Future<void> wakeDisplay() async {
    await _methodChannel.invokeMethod<void>('wakeDisplay');
  }
}
