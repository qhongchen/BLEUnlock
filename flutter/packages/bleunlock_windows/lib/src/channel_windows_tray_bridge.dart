import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';
import 'package:bleunlock_windows/src/windows_platform.dart';
import 'package:flutter/services.dart';

class ChannelWindowsTrayBridge implements WindowsTrayBridge {
  ChannelWindowsTrayBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ??
            const MethodChannel('bleunlock_windows/tray_methods'),
        _eventChannel =
            eventChannel ?? const EventChannel('bleunlock_windows/tray_events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Stream<Object?> get events => _eventChannel.receiveBroadcastStream();

  @override
  Future<void> setStatus(
    TrayStatus status, {
    String? recentDeviceSummary,
    bool isMonitoring = false,
  }) async {
    await _methodChannel.invokeMethod<void>(
      'setStatus',
      {
        'status': status.name,
        'isMonitoring': isMonitoring,
        if (recentDeviceSummary != null)
          'recentDeviceSummary': recentDeviceSummary,
      },
    );
  }

  @override
  Future<void> showQuickMenu() async {
    await _methodChannel.invokeMethod<void>('showQuickMenu');
  }
}
