import 'package:bleunlock_windows/src/windows_platform.dart';
import 'package:flutter/services.dart';

class ChannelWindowsStartupBridge implements WindowsStartupBridge {
  ChannelWindowsStartupBridge({MethodChannel? methodChannel})
      : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_windows/startup_methods');

  final MethodChannel _methodChannel;

  @override
  Future<bool> isEnabled() async {
    return await _methodChannel.invokeMethod<bool>('isEnabled') ?? false;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await _methodChannel.invokeMethod<void>(
      'setEnabled',
      {'enabled': enabled},
    );
  }
}
