import 'package:bleunlock_windows/src/windows_platform.dart';
import 'package:flutter/services.dart';

class ChannelWindowsUnlockBridge implements WindowsUnlockBridge {
  ChannelWindowsUnlockBridge({MethodChannel? methodChannel})
      : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_windows/unlock_methods');

  final MethodChannel _methodChannel;

  @override
  Future<Object?> refreshCapability() async {
    return _methodChannel.invokeMethod<Object?>('getUnlockCapability');
  }

  @override
  Future<void> openSettings() async {
    await _methodChannel.invokeMethod<void>('openUnlockSettings');
  }

  @override
  Future<Object?> unlock() async {
    return _methodChannel.invokeMethod<Object?>('unlock');
  }
}
