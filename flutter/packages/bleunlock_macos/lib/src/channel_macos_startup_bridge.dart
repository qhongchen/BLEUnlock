import 'package:bleunlock_macos/src/macos_platform.dart';
import 'package:flutter/services.dart';

class ChannelMacosStartupBridge implements MacosStartupBridge {
  ChannelMacosStartupBridge({MethodChannel? methodChannel})
      : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_macos/startup_methods');

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
