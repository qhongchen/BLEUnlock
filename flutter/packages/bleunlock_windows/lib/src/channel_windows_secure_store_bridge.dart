import 'package:bleunlock_windows/src/windows_platform.dart';
import 'package:flutter/services.dart';

class ChannelWindowsSecureStoreBridge implements WindowsSecureStoreBridge {
  ChannelWindowsSecureStoreBridge({MethodChannel? methodChannel})
      : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_windows/secure_store_methods');

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
