import 'package:bleunlock_macos/src/macos_platform.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';
import 'package:flutter/services.dart';

class ChannelMacosUnlockBridge implements MacosUnlockBridge {
  ChannelMacosUnlockBridge({MethodChannel? methodChannel})
      : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_macos/unlock_methods');

  final MethodChannel _methodChannel;

  @override
  CapabilityStatus get capability => const CapabilityStatus.supported();

  @override
  Future<Object?> refreshCapability() async {
    return _methodChannel.invokeMethod<Object?>('getCapability');
  }

  @override
  Future<void> openPermissionSettings() async {
    await _methodChannel.invokeMethod<void>('openPermissionSettings');
  }

  @override
  Future<Object?> unlock() async {
    return _methodChannel.invokeMethod<Object?>('unlock');
  }
}
