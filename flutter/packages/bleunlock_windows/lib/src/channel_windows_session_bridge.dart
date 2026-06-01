import 'package:bleunlock_windows/src/windows_platform.dart';
import 'package:flutter/services.dart';

class ChannelWindowsSessionBridge implements WindowsSessionBridge {
  ChannelWindowsSessionBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_windows/session_methods'),
        _eventChannel = eventChannel ??
            const EventChannel('bleunlock_windows/session_events');

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
