import 'package:bleunlock_macos/src/macos_platform.dart';
import 'package:flutter/services.dart';

class ChannelMacosSecureStoreBridge implements MacosSecureStoreBridge {
  ChannelMacosSecureStoreBridge({MethodChannel? methodChannel})
      : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_macos/secure_store_methods');

  final MethodChannel _methodChannel;

  @override
  Future<void> deleteSecret(String key) async {
    await _methodChannel.invokeMethod<void>(
      'deleteSecret',
      {'key': key},
    );
  }

  @override
  Future<String?> readSecret(String key) async {
    return _methodChannel.invokeMethod<String>(
      'readSecret',
      {'key': key},
    );
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    await _methodChannel.invokeMethod<void>(
      'writeSecret',
      {'key': key, 'value': value},
    );
  }
}
