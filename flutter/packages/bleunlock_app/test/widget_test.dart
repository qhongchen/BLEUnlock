import 'dart:convert';
import 'dart:io';

import 'package:bleunlock_app/src/controllers/app_coordinator.dart';
import 'package:bleunlock_app/src/home_page.dart';
import 'package:bleunlock_app/src/lock_sync/lock_sync_models.dart';
import 'package:bleunlock_app/src/platforms/mock_bleunlock_platform.dart';
import 'package:bleunlock_app/src/sections/device_section.dart';
import 'package:bleunlock_app/src/sections/log_section.dart';
import 'package:bleunlock_app/src/sections/overview_section.dart';
import 'package:bleunlock_app/src/sections/rules_section.dart';
import 'package:bleunlock_app/src/sections/system_section.dart';
import 'package:bleunlock_app/src/sections/validation_section.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_core/bleunlock_core.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders first-version BLEUnlock settings shell', (tester) async {
    final platform = MockBleunlockPlatform(
      scannerCapability: const CapabilityStatus.unsupported(),
      sessionCapability: const CapabilityStatus.unsupported(),
      storeCapability: const CapabilityStatus.unsupported(),
      trayCapability: const CapabilityStatus.unsupported(),
      startupCapability: const CapabilityStatus.unsupported(),
      unlockCapability: const CapabilityStatus.unsupported(),
    );
    final coordinator = AppCoordinator(platform: platform);

    await _pumpHomePage(tester, coordinator);

    expect(find.text('BLEUnlock'), findsOneWidget);
    expect(find.text('运行模式'), findsWidgets);
    expect(find.text('总览'), findsNothing);
    expect(find.text('设备'), findsNothing);
    expect(find.text('规则'), findsNothing);

    await tester.tap(find.text('系统'));
    await tester.pumpAndSettle();
    expect(find.text('系统'), findsWidgets);
    expect(find.text('刷新能力'), findsOneWidget);
    expect(find.text('不支持'), findsWidgets);

    await tester.tap(find.text('日志'));
    await tester.pumpAndSettle();
    expect(find.text('日志'), findsWidgets);
    expect(find.byIcon(Icons.article_outlined), findsWidgets);
    expect(find.text('验收'), findsNothing);

    await _disposeCoordinator(tester, coordinator);
  });

  testWidgets('device tab lists strongest RSSI first', (tester) async {
    final platform = MockBleunlockPlatform(
      unlockCapability: const CapabilityStatus.unsupported(),
    );
    final coordinator = AppCoordinator(platform: platform);

    await coordinator.updateLockSyncConfig(
      const LockSyncConfig(role: LockSyncRole.server),
    );
    await _pumpHomePage(tester, coordinator);

    await coordinator.startScanning();
    platform.emitScan(
      BleScanEvent(
        deviceId: 'weak',
        displayName: 'Weak band',
        rssi: -82,
        seenAt: DateTime(2026, 5, 28, 10),
      ),
    );
    platform.emitScan(
      BleScanEvent(
        deviceId: 'strong',
        displayName: 'Strong band',
        rssi: -42,
        seenAt: DateTime(2026, 5, 28, 10),
      ),
    );
    platform.emitScan(
      BleScanEvent(
        deviceId: 'middle',
        displayName: 'Middle band',
        rssi: -61,
        seenAt: DateTime(2026, 5, 28, 10),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('设备'));
    await tester.pumpAndSettle();

    final strongPosition =
        tester.getTopLeft(find.text('Strong band · ID strong'));
    final middlePosition =
        tester.getTopLeft(find.text('Middle band · ID middle'));
    final weakPosition = tester.getTopLeft(find.text('Weak band · ID weak'));

    expect(
        _visualOrder(strongPosition), lessThan(_visualOrder(middlePosition)));
    expect(_visualOrder(middlePosition), lessThan(_visualOrder(weakPosition)));

    await _disposeCoordinator(tester, coordinator);
  });

  testWidgets('device tab refresh button updates throttled BLE list',
      (tester) async {
    final platform = MockBleunlockPlatform(
      unlockCapability: const CapabilityStatus.unsupported(),
    );
    final coordinator = AppCoordinator(
      platform: platform,
      deviceListRefreshInterval: const Duration(seconds: 5),
    );

    await coordinator.updateLockSyncConfig(
      const LockSyncConfig(role: LockSyncRole.server),
    );
    await _pumpHomePage(tester, coordinator);
    await coordinator.startScanning();
    platform.emitScan(
      BleScanEvent(
        deviceId: 'band-1',
        displayName: 'Xiaomi Smart Band',
        rssi: -80,
        seenAt: DateTime(2026, 5, 28, 10),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('设备'));
    await tester.pumpAndSettle();
    expect(find.text('-80 dBm'), findsOneWidget);

    platform.emitScan(
      BleScanEvent(
        deviceId: 'band-1',
        displayName: 'Xiaomi Smart Band',
        rssi: -40,
        seenAt: DateTime(2026, 5, 28, 10, 0, 1),
      ),
    );
    await tester.pump();
    expect(find.text('-80 dBm'), findsOneWidget);
    expect(find.text('-40 dBm'), findsNothing);

    await tester.tap(find.text('刷新设备'));
    await tester.pump();
    expect(find.text('-40 dBm'), findsOneWidget);

    await _disposeCoordinator(tester, coordinator);
  });

  testWidgets('device tab uses responsive grid for scan efficiency',
      (tester) async {
    final devices = [
      for (var index = 0; index < 8; index += 1)
        DashboardDeviceView(
          id: 'device-$index',
          idLabel: 'ID device-$index',
          name: 'Device $index',
          rssiLabel: '-4$index dBm',
          lastSeenLabel: 'Last seen 10:00:0$index',
          presenceLabel: 'Visible',
          isSelected: index == 0,
        ),
    ];

    await _pumpDeviceSectionInWidth(tester, width: 760, devices: devices);

    final twoColumnFirstTop =
        tester.getTopLeft(find.text('Device 0 · ID device-0')).dy;
    final twoColumnSecondTop =
        tester.getTopLeft(find.text('Device 1 · ID device-1')).dy;
    final twoColumnThirdTop =
        tester.getTopLeft(find.text('Device 2 · ID device-2')).dy;

    expect(twoColumnSecondTop, twoColumnFirstTop);
    expect(twoColumnThirdTop, greaterThan(twoColumnFirstTop));

    await _pumpDeviceSectionInWidth(tester, width: 1080, devices: devices);

    final threeColumnFirstTop =
        tester.getTopLeft(find.text('Device 0 · ID device-0')).dy;
    final threeColumnSecondTop =
        tester.getTopLeft(find.text('Device 1 · ID device-1')).dy;
    final threeColumnThirdTop =
        tester.getTopLeft(find.text('Device 2 · ID device-2')).dy;
    final threeColumnFourthTop =
        tester.getTopLeft(find.text('Device 3 · ID device-3')).dy;

    expect(threeColumnSecondTop, threeColumnFirstTop);
    expect(threeColumnThirdTop, threeColumnFirstTop);
    expect(threeColumnFourthTop, greaterThan(threeColumnFirstTop));
  });

  testWidgets('device grid keeps selected device controls visible',
      (tester) async {
    const devices = [
      DashboardDeviceView(
        id: 'band-1',
        idLabel: 'ID band-1',
        name: 'Xiaomi Smart Band',
        rssiLabel: '-48 dBm',
        lastSeenLabel: 'Last seen 10:00:01',
        presenceLabel: 'close',
        isSelected: true,
      ),
    ];

    await _pumpDeviceSectionInWidth(tester, width: 760, devices: devices);

    expect(find.text('Xiaomi Smart Band · ID band-1'), findsOneWidget);
    expect(find.text('-48 dBm'), findsOneWidget);
    expect(find.byIcon(Icons.sensors), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('device tab fits more devices above fold in grid layout',
      (tester) async {
    final devices = [
      for (var index = 0; index < 8; index += 1)
        DashboardDeviceView(
          id: 'device-$index',
          idLabel: 'ID device-$index',
          name: 'Device $index',
          rssiLabel: '-4$index dBm',
          lastSeenLabel: 'Last seen 10:00:0$index',
          presenceLabel: 'Visible',
          isSelected: index == 0,
        ),
    ];

    await _pumpDeviceSectionInWidth(tester, width: 760, devices: devices);

    expect(find.text('Device 0 · ID device-0'), findsOneWidget);
    expect(find.text('Device 7 · ID device-7'), findsOneWidget);

    final firstTop = tester.getTopLeft(find.text('Device 0 · ID device-0')).dy;
    final lastTop = tester.getTopLeft(find.text('Device 7 · ID device-7')).dy;
    expect(lastTop - firstTop, lessThan(360));
  });

  testWidgets('scan and select device updates dashboard state', (tester) async {
    final platform = MockBleunlockPlatform(
      unlockCapability: const CapabilityStatus.unsupported(),
    );
    final coordinator = AppCoordinator(platform: platform);

    await _pumpHomePage(tester, coordinator);

    await coordinator.startScanning();
    await tester.pump();

    expect(find.text('扫描中'), findsOneWidget);
    expect(platform.mockScanner.isScanning, isTrue);

    platform.emitScan(
      BleScanEvent(
        deviceId: 'band-1',
        displayName: 'Xiaomi Smart Band',
        rssi: -50,
        seenAt: DateTime(2026, 5, 28, 10),
      ),
    );
    await tester.pump();

    expect(coordinator.value.devices.single.name, 'Xiaomi Smart Band');
    expect(coordinator.value.devices.single.idLabel, 'ID band-1');
    expect(coordinator.value.devices.single.rssiLabel, '-50 dBm');
    expect(
      coordinator.value.devices.single.lastSeenLabel,
      'Last seen 10:00:00',
    );

    coordinator.setDeviceSelected('band-1', true);
    await tester.pump();

    expect(coordinator.value.devices.single.isSelected, isTrue);

    await _disposeCoordinator(tester, coordinator);
  });

  testWidgets('shows a hint when monitoring is blocked by no selection',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceSection(
            devices: const [
              DashboardDeviceView(
                id: 'band-1',
                idLabel: 'ID band-1',
                name: 'Xiaomi Smart Band',
                rssiLabel: '-50 dBm',
                lastSeenLabel: 'Last seen 10:00:00',
                presenceLabel: 'Idle',
                isSelected: false,
              ),
            ],
            isMonitoring: false,
            onStartScanning: () {},
            onRefreshDevices: () {},
            onStartMonitoring: () {},
            onPauseScanning: () {},
            onDeviceSelectionChanged: (_, __) {},
          ),
        ),
      ),
    );

    expect(
      find.text('请先选择一个或多个设备，再开始监听。'),
      findsOneWidget,
    );
  });

  testWidgets('overview quick action locks immediately', (tester) async {
    final platform = MockBleunlockPlatform(
      unlockCapability: const CapabilityStatus.unsupported(),
    );
    final coordinator = AppCoordinator(platform: platform);

    await _pumpHomePage(tester, coordinator);

    expect(find.byTooltip('开始监听'), findsOneWidget);
    expect(find.byTooltip('立即锁屏'), findsOneWidget);

    await tester.tap(find.byTooltip('立即锁屏'));
    await tester.pump();

    expect(platform.mockSession.lockCount, 1);
    expect(coordinator.value.snapshot.lastActionLabel, 'Locked screen');

    await _disposeCoordinator(tester, coordinator);
  });

  testWidgets('overview shows monitoring hint when no device is selected',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewSection(
            snapshot: const DashboardSnapshot(
              monitoringStatus: 'Monitoring paused',
              stateLabel: 'Idle',
              bestRssi: null,
              selectedDeviceCount: 0,
              lastActionLabel: 'Select a device first',
              bluetoothCapabilityLabel: 'supported',
              autoLockCapabilityLabel: 'supported',
              wakeCapabilityLabel: 'supported',
              autoUnlockCapabilityLabel: 'unsupported',
              trayCapabilityLabel: 'supported',
              startupCapabilityLabel: 'supported',
              startupEnabled: false,
              autoUnlockSecretConfigured: false,
              autoUnlockSecretEditable: false,
              autoUnlockPermissionSettingsAvailable: false,
            ),
            isMonitoring: false,
            canStartMonitoring: false,
            monitoringHint:
                'Select one or more devices in Devices before starting monitoring.',
            onStartMonitoring: () {},
            onPauseMonitoring: () {},
            onLockNow: () {},
          ),
        ),
      ),
    );

    expect(
      find.text('请先在设备列表中选择一个或多个设备，再开始监听。'),
      findsOneWidget,
    );
  });

  testWidgets('rules controls emit updated config', (tester) async {
    ProximityConfig latest = const ProximityConfig();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RulesSection(
              config: latest,
              onConfigChanged: (config) {
                latest = config;
              },
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('靠近逻辑'));
    await tester.tap(find.text('全部').first);
    await tester.pump();

    expect(latest.unlockDeviceLogic, UnlockDeviceLogic.allClose);
    expect(find.text('靠近时唤醒'), findsNothing);
    expect(find.text('macOS 自动解锁'), findsNothing);
  });

  testWidgets('system controls emit wake and auto unlock changes',
      (tester) async {
    var wakeOnProximity = false;
    var macAutoUnlockEnabled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SystemSection(
              snapshot: const DashboardSnapshot(
                monitoringStatus: 'Monitoring paused',
                stateLabel: 'Idle',
                bestRssi: null,
                selectedDeviceCount: 0,
                lastActionLabel: 'None',
                bluetoothCapabilityLabel: 'supported',
                autoLockCapabilityLabel: 'supported',
                wakeCapabilityLabel: 'supported',
                autoUnlockCapabilityLabel: 'supported',
                trayCapabilityLabel: 'supported',
                startupCapabilityLabel: 'supported',
                startupEnabled: false,
                autoUnlockSecretConfigured: true,
                autoUnlockSecretEditable: true,
                autoUnlockPermissionSettingsAvailable: false,
              ),
              wakeOnProximity: wakeOnProximity,
              macAutoUnlockEnabled: macAutoUnlockEnabled,
              canConfigureMacAutoUnlock: true,
              macAutoUnlockStatusLabel: 'supported',
              onCapabilitiesRefreshed: () async {},
              onStartupChanged: (_) {},
              onWakeOnProximityChanged: (value) {
                wakeOnProximity = value;
              },
              onMacAutoUnlockChanged: (value) {
                macAutoUnlockEnabled = value;
              },
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('靠近时唤醒'));
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(wakeOnProximity, isTrue);

    await tester.ensureVisible(find.text('macOS 自动解锁'));
    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();

    expect(macAutoUnlockEnabled, isTrue);
  });

  testWidgets('system auto unlock switch is disabled when unsupported',
      (tester) async {
    var wasCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SystemSection(
              snapshot: const DashboardSnapshot(
                monitoringStatus: 'Monitoring paused',
                stateLabel: 'Idle',
                bestRssi: null,
                selectedDeviceCount: 0,
                lastActionLabel: 'None',
                bluetoothCapabilityLabel: 'supported',
                autoLockCapabilityLabel: 'supported',
                wakeCapabilityLabel: 'supported',
                autoUnlockCapabilityLabel: 'unsupported',
                trayCapabilityLabel: 'supported',
                startupCapabilityLabel: 'supported',
                startupEnabled: false,
                autoUnlockSecretConfigured: false,
                autoUnlockSecretEditable: false,
                autoUnlockPermissionSettingsAvailable: false,
              ),
              wakeOnProximity: false,
              macAutoUnlockEnabled: false,
              canConfigureMacAutoUnlock: false,
              macAutoUnlockStatusLabel: 'unsupported',
              onCapabilitiesRefreshed: () async {},
              onStartupChanged: (_) {},
              onWakeOnProximityChanged: (_) {},
              onMacAutoUnlockChanged: (_) {
                wasCalled = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('macOS 自动解锁'));
    await tester.tap(find.byType(Switch).last);
    await tester.pump();

    expect(wasCalled, isFalse);
    expect(find.text('不支持'), findsOneWidget);
  });

  testWidgets('system auto unlock switch shows missing password status',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SystemSection(
              snapshot: const DashboardSnapshot(
                monitoringStatus: 'Monitoring paused',
                stateLabel: 'Idle',
                bestRssi: null,
                selectedDeviceCount: 0,
                lastActionLabel: 'None',
                bluetoothCapabilityLabel: 'supported',
                autoLockCapabilityLabel: 'supported',
                wakeCapabilityLabel: 'supported',
                autoUnlockCapabilityLabel: 'missing secret',
                trayCapabilityLabel: 'supported',
                startupCapabilityLabel: 'supported',
                startupEnabled: false,
                autoUnlockSecretConfigured: false,
                autoUnlockSecretEditable: true,
                autoUnlockPermissionSettingsAvailable: false,
              ),
              wakeOnProximity: false,
              macAutoUnlockEnabled: true,
              canConfigureMacAutoUnlock: true,
              macAutoUnlockStatusLabel: 'missing secret',
              onCapabilitiesRefreshed: () async {},
              onStartupChanged: (_) {},
              onWakeOnProximityChanged: (_) {},
              onMacAutoUnlockChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('macOS 自动解锁'));
    await tester.pump();

    expect(find.text('缺少密码'), findsOneWidget);
    expect(find.text('macOS 解锁密码'), findsNothing);
  });

  testWidgets('unsupported auto unlock does not show password input',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SystemSection(
            snapshot: const DashboardSnapshot(
              monitoringStatus: 'Monitoring paused',
              stateLabel: 'Idle',
              bestRssi: null,
              selectedDeviceCount: 0,
              lastActionLabel: 'None',
              bluetoothCapabilityLabel: 'supported',
              autoLockCapabilityLabel: 'supported',
              wakeCapabilityLabel: 'supported',
              autoUnlockCapabilityLabel: 'unsupported',
              trayCapabilityLabel: 'supported',
              startupCapabilityLabel: 'supported',
              startupEnabled: false,
              autoUnlockSecretConfigured: false,
              autoUnlockSecretEditable: false,
              autoUnlockPermissionSettingsAvailable: false,
            ),
            wakeOnProximity: false,
            macAutoUnlockEnabled: false,
            canConfigureMacAutoUnlock: false,
            macAutoUnlockStatusLabel: 'unsupported',
            onCapabilitiesRefreshed: () async {},
            onStartupChanged: (_) {},
            onWakeOnProximityChanged: (_) {},
            onMacAutoUnlockChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('macOS 自动解锁'), findsOneWidget);
    expect(find.text('不支持'), findsOneWidget);
    expect(find.text('macOS 解锁密码'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'supported auto unlock does not show password input before enabled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SystemSection(
            snapshot: const DashboardSnapshot(
              monitoringStatus: 'Monitoring paused',
              stateLabel: 'Idle',
              bestRssi: null,
              selectedDeviceCount: 0,
              lastActionLabel: 'None',
              bluetoothCapabilityLabel: 'supported',
              autoLockCapabilityLabel: 'supported',
              wakeCapabilityLabel: 'supported',
              autoUnlockCapabilityLabel: 'missing secret',
              trayCapabilityLabel: 'supported',
              startupCapabilityLabel: 'supported',
              startupEnabled: false,
              autoUnlockSecretConfigured: false,
              autoUnlockSecretEditable: true,
              autoUnlockPermissionSettingsAvailable: false,
            ),
            wakeOnProximity: false,
            macAutoUnlockEnabled: false,
            canConfigureMacAutoUnlock: true,
            macAutoUnlockStatusLabel: 'missing secret',
            onCapabilitiesRefreshed: () async {},
            onStartupChanged: (_) {},
            onWakeOnProximityChanged: (_) {},
            onMacAutoUnlockChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('macOS 自动解锁'), findsOneWidget);
    expect(find.text('缺少密码'), findsOneWidget);
    expect(find.text('macOS 解锁密码'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('opens macOS accessibility settings when permission is denied',
      (tester) async {
    final platform = MockBleunlockPlatform(
      unlockCapability: const CapabilityStatus.permissionDenied(
        'Accessibility permission is required',
      ),
      platformLabel: 'macos',
    );
    final coordinator = AppCoordinator(platform: platform);

    await coordinator.refreshSystemSettings();
    await _pumpHomePage(tester, coordinator);
    await tester.pump();

    expect(
      coordinator.value.snapshot.autoUnlockPermissionSettingsAvailable,
      isTrue,
    );

    await coordinator.openMacAutoUnlockPermissionSettings();
    await tester.pump();

    expect(platform.mockUnlock.openPermissionSettingsCount, 1);
    expect(
      coordinator.value.snapshot.lastActionLabel,
      'Accessibility settings opened',
    );

    await _disposeCoordinator(tester, coordinator);
  });

  testWidgets('system section only shows actionable Windows controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SystemSection(
            snapshot: const DashboardSnapshot(
              platformLabel: 'Windows',
              monitoringStatus: 'Monitoring paused',
              stateLabel: 'Idle',
              bestRssi: null,
              selectedDeviceCount: 0,
              lastActionLabel: 'None',
              bluetoothCapabilityLabel: 'supported',
              autoLockCapabilityLabel: 'supported',
              wakeCapabilityLabel: 'supported',
              autoUnlockCapabilityLabel: 'unsupported',
              trayCapabilityLabel: 'supported',
              startupCapabilityLabel: 'supported',
              startupEnabled: false,
              autoUnlockSecretConfigured: false,
              autoUnlockSecretEditable: false,
              autoUnlockPermissionSettingsAvailable: false,
            ),
            wakeOnProximity: false,
            macAutoUnlockEnabled: false,
            canConfigureMacAutoUnlock: false,
            macAutoUnlockStatusLabel: 'unsupported',
            onCapabilitiesRefreshed: () async {},
            onStartupChanged: (_) {},
            onWakeOnProximityChanged: (_) {},
            onMacAutoUnlockChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Windows Credential Provider 组件未安装'), findsNothing);
    expect(find.text('Windows'), findsNothing);
    expect(find.text('刷新能力'), findsOneWidget);
    expect(find.text('macOS 自动解锁'), findsOneWidget);
  });

  testWidgets('validation section shows Windows Credential Provider pill', (
    tester,
  ) async {
    final state = DashboardState(
      snapshot: const DashboardSnapshot(
        platformLabel: 'Windows',
        monitoringStatus: 'Monitoring paused',
        stateLabel: 'Idle',
        bestRssi: null,
        selectedDeviceCount: 0,
        lastActionLabel: 'None',
        bluetoothCapabilityLabel: 'supported',
        autoLockCapabilityLabel: 'supported',
        wakeCapabilityLabel: 'supported',
        autoUnlockCapabilityLabel: 'unsupported',
        trayCapabilityLabel: 'supported',
        startupCapabilityLabel: 'supported',
        startupEnabled: false,
        autoUnlockSecretConfigured: false,
        autoUnlockSecretEditable: false,
        autoUnlockPermissionSettingsAvailable: false,
      ),
      devices: const [],
      logs: const [],
      config: const ProximityConfig(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ValidationSection(state: state),
          ),
        ),
      ),
    );

    expect(find.text('Windows Credential Provider 组件未安装'), findsWidgets);
  });

  testWidgets('refreshes capabilities from system section', (tester) async {
    final platform = MockBleunlockPlatform(
      scannerCapability: const CapabilityStatus.poweredOff('Bluetooth off'),
    );
    platform.mockScanner.refreshedCapability =
        const CapabilityStatus.supported();
    final coordinator = AppCoordinator(platform: platform);

    await _pumpHomePage(tester, coordinator);
    await tester.pump();

    await tester.tap(find.text('系统'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('刷新能力'));
    await tester.pumpAndSettle();
    final refreshCountBeforeTap = platform.mockScanner.refreshCapabilityCount;
    await tester.tap(find.text('刷新能力'));
    await tester.pump();

    expect(
      platform.mockScanner.refreshCapabilityCount,
      refreshCountBeforeTap + 1,
    );
    expect(coordinator.value.snapshot.bluetoothCapabilityLabel, 'supported');
    expect(
      coordinator.value.snapshot.lastActionLabel,
      'Capabilities refreshed',
    );

    await _disposeCoordinator(tester, coordinator);
  });

  testWidgets('logs show structured diagnostic details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              LogSection(
                logs: [
                  DashboardLogEntry(
                    timestamp: DateTime(2026, 5, 28, 10, 11, 12),
                    category: DashboardLogCategory.scan,
                    message: 'Scan band-1 -52 dBm',
                    platform: 'mock',
                    deviceId: 'band-1',
                    rssi: -52,
                    reason: 'bleAdvertisement',
                    sessionState: DashboardSessionState.unlocked,
                  ),
                  DashboardLogEntry(
                    timestamp: DateTime(2026, 5, 28, 10, 11, 17),
                    category: DashboardLogCategory.scan,
                    message: 'Scan band-1 -58 dBm',
                    platform: 'mock',
                    deviceId: 'band-1',
                    rssi: -58,
                    reason: 'bleAdvertisement',
                    sessionState: DashboardSessionState.locked,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('10:11:12'), findsOneWidget);
    expect(find.text('显示 2 / 2 条'), findsOneWidget);
    expect(find.text('验收就绪度'), findsNothing);
    expect(find.text('复制验收清单'), findsNothing);
    expect(find.text('导出验收包'), findsNothing);
    expect(find.text('会话诊断'), findsOneWidget);
    expect(
      find.text('日志 1 · 扫描 1 · 最新事件 10:11:12'),
      findsOneWidget,
    );
    expect(find.text('最新扫描 10:11:12 · 设备 band-1'), findsOneWidget);
    expect(find.text('已观测到 BLE 扫描'), findsWidgets);
    expect(find.text('设备诊断'), findsOneWidget);
    expect(find.text('身份稳定'), findsOneWidget);
    expect(find.text('-55 dBm 平均'), findsOneWidget);
    expect(find.text('-58 至 -52 dBm'), findsOneWidget);
    expect(find.text('平均间隔 5s · 最长静默 5s'), findsOneWidget);
    expect(find.text('全部级别'), findsOneWidget);
    expect(find.text('全部会话'), findsOneWidget);
    expect(find.text('搜索日志'), findsOneWidget);
    expect(find.text('复制会话摘要'), findsOneWidget);
    expect(find.text('复制验收清单'), findsNothing);
    expect(find.text('复制诊断日志'), findsOneWidget);
    expect(find.text('导出诊断日志'), findsOneWidget);
    expect(find.text('导出验收包'), findsNothing);
    expect(find.text('扫描 band-1 -52 dBm'), findsOneWidget);
    expect(
      find.text(
        '级别=信息 平台=mock 设备=band-1 RSSI=-52 原因=bleAdvertisement 会话=未锁定',
      ),
      findsOneWidget,
    );
  });

  testWidgets('logs hide low-value diagnostics until detailed mode is enabled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              LogSection(
                logs: [
                  DashboardLogEntry(
                    timestamp: DateTime(2026, 5, 28, 10, 11, 12),
                    category: DashboardLogCategory.decision,
                    message: 'Decision belowVisibleThreshold',
                    reason: 'belowVisibleThreshold',
                  ),
                  DashboardLogEntry(
                    timestamp: DateTime(2026, 5, 28, 10, 11, 13),
                    category: DashboardLogCategory.decision,
                    message: 'Decision unmonitored',
                    reason: 'unmonitored',
                  ),
                  DashboardLogEntry(
                    timestamp: DateTime(2026, 5, 28, 10, 11, 14),
                    category: DashboardLogCategory.scan,
                    message: 'Scan band-1 -52 dBm',
                    deviceId: 'band-1',
                    rssi: -52,
                  ),
                  DashboardLogEntry(
                    timestamp: DateTime(2026, 5, 28, 10, 11, 15),
                    category: DashboardLogCategory.action,
                    message: 'Monitoring started',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('显示 2 / 4 条'), findsOneWidget);
    expect(find.text('判定 belowVisibleThreshold'), findsNothing);
    expect(find.text('判定 unmonitored'), findsNothing);
    expect(find.text('扫描 band-1 -52 dBm'), findsOneWidget);
    expect(find.text('监听已开始'), findsOneWidget);

    await tester.tap(find.text('详细诊断'));
    await tester.pumpAndSettle();

    expect(find.text('显示 4 / 4 条'), findsOneWidget);
    expect(find.text('判定 belowVisibleThreshold'), findsOneWidget);
    expect(find.text('判定 unmonitored'), findsOneWidget);
  });

  testWidgets('acceptance readiness shows runtime action checklist',
      (tester) async {
    final logs = [
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 12),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
        sessionState: DashboardSessionState.locked,
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 15),
        category: DashboardLogCategory.decision,
        message: 'Decision close',
        reason: 'close',
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 18),
        category: DashboardLogCategory.action,
        message: 'Locked screen',
        reason: 'proximityDecision',
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 20),
        category: DashboardLogCategory.action,
        message: 'Wake requested',
        reason: 'proximityDecision',
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 22),
        category: DashboardLogCategory.action,
        message: 'Unlocked session',
        reason: 'autoUnlockSucceeded',
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 24),
        category: DashboardLogCategory.action,
        message: 'Open settings requested',
        reason: 'trayAction',
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 26),
        category: DashboardLogCategory.action,
        message: 'Startup enabled',
        reason: 'startupChanged',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: DashboardState(
                  snapshot: const DashboardSnapshot(
                    monitoringStatus: 'Monitoring',
                    stateLabel: 'Locked',
                    bestRssi: -52,
                    selectedDeviceCount: 1,
                    lastActionLabel: 'Unlocked session',
                    bluetoothCapabilityLabel: 'supported',
                    autoLockCapabilityLabel: 'supported',
                    wakeCapabilityLabel: 'supported',
                    autoUnlockCapabilityLabel: 'supported',
                    trayCapabilityLabel: 'supported',
                    startupCapabilityLabel: 'supported',
                    startupEnabled: true,
                    autoUnlockSecretConfigured: true,
                    autoUnlockSecretEditable: true,
                    autoUnlockPermissionSettingsAvailable: false,
                  ),
                  devices: const [
                    DashboardDeviceView(
                      id: 'band-1',
                      idLabel: 'ID band-1',
                      name: 'Xiaomi Smart Band',
                      rssiLabel: '-52 dBm',
                      lastSeenLabel: 'Last seen 10:11:12',
                      presenceLabel: 'Close',
                      isSelected: true,
                    ),
                  ],
                  logs: logs,
                  config: const ProximityConfig(enableMacAutoUnlock: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('自动锁屏已捕获'), findsOneWidget);
    expect(find.text('唤醒已捕获'), findsOneWidget);
    expect(find.text('自动解锁 已捕获'), findsOneWidget);
    expect(find.text('托盘已捕获'), findsOneWidget);
    expect(find.text('开机启动已捕获'), findsOneWidget);
    expect(find.text('必需证据已捕获 10/15'), findsOneWidget);
    expect(find.text('运行验收未完成 · 缺少 5 项'), findsOneWidget);
    expect(find.text('整体验收阻塞 · 11 项'), findsOneWidget);
    expect(find.text('外部验收未完成'), findsOneWidget);
    expect(find.text('验收步骤'), findsOneWidget);
    expect(find.text('BLE 扫描'), findsOneWidget);
    expect(
      find.text('已捕获 3/3 · 最新 10:11:15', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('托盘菜单'), findsOneWidget);
    expect(
      find.text('已捕获 1/5 · 最新 10:11:24', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('开机启动'), findsOneWidget);
    expect(
      find.text('已捕获 1/2 · 最新 10:11:26', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('缺少的必需证据'), findsOneWidget);
    expect(find.text('下一步验收动作'), findsOneWidget);
    expect(find.text('外部验证门禁'), findsOneWidget);
    expect(find.text('外部门禁已解决 0/6'), findsOneWidget);
    expect(find.text('外部门禁待处理 6'), findsOneWidget);
    expect(find.text('外部门禁失败 0'), findsOneWidget);
    expect(find.text('Windows 构建验证'), findsOneWidget);
    expect(find.text('真实 BLE 扫描'), findsWidgets);
    expect(find.text('锁屏扫描连续性'), findsOneWidget);
    expect(find.text('macOS 辅助功能解锁'), findsOneWidget);
    expect(find.text('托盘动作'), findsOneWidget);
    expect(find.text('开机启动动作'), findsWidgets);
    expect(
      find.byKey(const ValueKey('gate-windowsBuild-result')),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('gate-windowsBuild-panel')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gate-windowsBuild-panel')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('gate-windowsBuild-result')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('gate-realBleScan-result')),
      findsNothing,
    );
    expect(
      find.textContaining(
        '使用托盘菜单执行 开始监听',
        skipOffstage: false,
      ),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('托盘开始监听'), findsAtLeastNWidgets(1));
    expect(find.text('关闭开机启动'), findsAtLeastNWidgets(1));
    expect(find.text('复制验收手册'), findsOneWidget);
    expect(find.text('复制缺失动作'), findsOneWidget);
    expect(find.text('验收手册'), findsOneWidget);
    expect(find.text('缺失验收步骤'), findsOneWidget);
    expect(find.text('扫描附近已选择的 BLE 设备'), findsOneWidget);
    expect(
      find.text('触发自动锁屏与唤醒', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('使用每个托盘菜单动作', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.text('缺少 托盘开始监听、托盘暂停监听、托盘立即锁屏、托盘退出'),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.textContaining(
        '下一步 使用托盘菜单执行 开始监听',
        skipOffstage: false,
      ),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.textContaining(
        '下一步 关闭开机启动',
        skipOffstage: false,
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('acceptance readiness shows evidence counts and latest time',
      (tester) async {
    final logs = [
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 0, 5),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -55 dBm',
        deviceId: 'band-1',
        rssi: -55,
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 0, 7),
        category: DashboardLogCategory.action,
        message: 'Open settings requested',
        reason: 'trayAction',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: DashboardState(
                  snapshot: const DashboardSnapshot.initial(),
                  devices: const [],
                  logs: logs,
                  config: const ProximityConfig(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('证据详情'), findsOneWidget);
    expect(find.text('真实 BLE 扫描'), findsAtLeastNWidgets(1));
    expect(find.text('2 条证据 · 最新 10:00:05'), findsOneWidget);
    expect(find.text('托盘打开设置'), findsOneWidget);
    expect(find.text('1 条证据 · 最新 10:00:07'), findsAtLeastNWidgets(1));
    expect(find.text('托盘开始监听'), findsAtLeastNWidgets(1));
    expect(find.text('0 条证据'), findsWidgets);
  });

  testWidgets('validation section exposes and copies validation session id',
      (tester) async {
    var clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                validationSessionId: 'validation-manual-001',
                state: const DashboardState(
                  snapshot: DashboardSnapshot.initial(),
                  devices: [],
                  logs: [],
                  config: ProximityConfig(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('会话 validation-manual-001'), findsOneWidget);

    await tester.ensureVisible(find.text('复制验证 ID'));
    await tester.tap(find.text('复制验证 ID'));
    await tester.pump();

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboard?.text, 'validation-manual-001');
    expect(find.text('验证 ID 已复制'), findsOneWidget);
  });

  testWidgets('validation section exposes and copies export directory',
      (tester) async {
    var clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final exportDirectory = Directory(
      '${Directory.systemTemp.path}/bleunlock-validation-export-path-test',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                validationSessionId: 'validation-manual-001',
                exportDirectory: exportDirectory,
                state: const DashboardState(
                  snapshot: DashboardSnapshot.initial(),
                  devices: [],
                  logs: [],
                  config: ProximityConfig(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.textContaining('导出路径 ${exportDirectory.path}'),
      findsOneWidget,
    );
    expect(find.textContaining(exportDirectory.path), findsOneWidget);

    await tester.ensureVisible(find.text('复制导出路径'));
    await tester.tap(find.text('复制导出路径'));
    await tester.pump();

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboard?.text, exportDirectory.path);
    expect(find.text('导出路径已复制'), findsOneWidget);
  });

  testWidgets('acceptance readiness marks unsupported auto unlock',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: DashboardState(
                  snapshot: const DashboardSnapshot(
                    monitoringStatus: 'Monitoring paused',
                    stateLabel: 'Idle',
                    bestRssi: null,
                    selectedDeviceCount: 0,
                    lastActionLabel: 'None',
                    bluetoothCapabilityLabel: 'supported',
                    autoLockCapabilityLabel: 'supported',
                    wakeCapabilityLabel: 'supported',
                    autoUnlockCapabilityLabel: 'unsupported',
                    trayCapabilityLabel: 'supported',
                    startupCapabilityLabel: 'supported',
                    startupEnabled: false,
                    autoUnlockSecretConfigured: false,
                    autoUnlockSecretEditable: false,
                    autoUnlockPermissionSettingsAvailable: false,
                  ),
                  devices: const [],
                  logs: [],
                  config: ProximityConfig(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('自动解锁 不支持'), findsOneWidget);
    expect(find.text('自动解锁 缺失'), findsNothing);
    expect(find.text('必需证据已捕获 0/14'), findsOneWidget);
    expect(find.text('macOS 自动解锁动作'), findsOneWidget);
    expect(find.text('0 条证据'), findsWidgets);
  });

  testWidgets('Windows acceptance excludes macOS unlock gate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: DashboardState(
                  snapshot: const DashboardSnapshot(
                    platformLabel: 'Windows',
                    monitoringStatus: 'Monitoring paused',
                    stateLabel: 'Idle',
                    bestRssi: null,
                    selectedDeviceCount: 0,
                    lastActionLabel: 'None',
                    bluetoothCapabilityLabel: 'supported',
                    autoLockCapabilityLabel: 'supported',
                    wakeCapabilityLabel: 'supported',
                    autoUnlockCapabilityLabel: 'unsupported',
                    trayCapabilityLabel: 'supported',
                    startupCapabilityLabel: 'supported',
                    startupEnabled: false,
                    autoUnlockSecretConfigured: false,
                    autoUnlockSecretEditable: false,
                    autoUnlockPermissionSettingsAvailable: false,
                  ),
                  devices: const [],
                  logs: [],
                  config: const ProximityConfig(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Windows Credential Provider 组件未安装'), findsOneWidget);
    expect(find.text('自动解锁 不支持'), findsOneWidget);
    expect(find.text('必需证据已捕获 0/15'), findsOneWidget);
    expect(find.text('外部门禁待处理 6'), findsNothing);
    expect(find.text('外部门禁待处理 5'), findsOneWidget);
    expect(find.text('macOS 辅助功能解锁'), findsNothing);
    expect(find.text('Windows Credential Provider 组件'), findsWidgets);
    expect(find.text('已捕获 0/1'), findsWidgets);
  });

  testWidgets('acceptance readiness shows tray menu action checklist',
      (tester) async {
    final logs = [
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10),
        category: DashboardLogCategory.action,
        message: 'Open settings requested',
        reason: 'trayAction',
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 0, 1),
        category: DashboardLogCategory.action,
        message: 'Locked screen',
        reason: 'trayAction',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: DashboardState(
                  snapshot: const DashboardSnapshot.initial(),
                  devices: const [],
                  logs: logs,
                  config: const ProximityConfig(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('托盘打开 已捕获'), findsOneWidget);
    expect(find.text('托盘开始 缺失'), findsOneWidget);
    expect(find.text('托盘暂停 缺失'), findsOneWidget);
    expect(find.text('托盘锁屏 已捕获'), findsOneWidget);
    expect(find.text('托盘退出 缺失'), findsOneWidget);
  });

  testWidgets('acceptance readiness shows startup enable disable checklist',
      (tester) async {
    final logs = [
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10),
        category: DashboardLogCategory.action,
        message: 'Startup enabled',
        reason: 'startupChanged',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: DashboardState(
                  snapshot: const DashboardSnapshot.initial(),
                  devices: const [],
                  logs: logs,
                  config: const ProximityConfig(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('开机启动已捕获'), findsOneWidget);
    expect(find.text('开启开机启动 已捕获'), findsOneWidget);
    expect(find.text('关闭开机启动 缺失'), findsOneWidget);
  });

  testWidgets('exports visible diagnostic logs as json lines', (tester) async {
    final exportDirectory = Directory.systemTemp.createTempSync(
      'bleunlock_diagnostics_test_',
    );
    addTearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              LogSection(
                logs: [
                  DashboardLogEntry(
                    timestamp: DateTime(2026, 5, 28, 10, 11, 12),
                    category: DashboardLogCategory.scan,
                    message: 'Scan band-1 -52 dBm',
                    platform: 'mock',
                    deviceId: 'band-1',
                    rssi: -52,
                    reason: 'bleAdvertisement',
                    sessionState: DashboardSessionState.unlocked,
                  ),
                ],
                exportDirectory: exportDirectory,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('导出诊断日志'));
    await tester.tap(find.text('导出诊断日志'));
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20; attempt += 1) {
        final hasExportContent = exportDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.jsonl'))
            .any(
              (file) => file.readAsStringSync().contains('"deviceId":"band-1"'),
            );
        if (hasExportContent) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();

    final files = exportDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.jsonl'))
        .toList();
    expect(files, hasLength(1));
    expect(
      files.single.path,
      contains('bleunlock-diagnostics-'),
    );
    expect(files.single.readAsStringSync(), contains('"deviceId":"band-1"'));
    expect(
      files.single.readAsStringSync(),
      isNot(contains('"validationSessionId"')),
    );
    expect(
        files.single.readAsStringSync(), contains('"sessionState":"unlocked"'));
    expect(find.textContaining('诊断日志已导出：'), findsOneWidget);
  });

  testWidgets('exports acceptance bundle before any log is recorded',
      (tester) async {
    final exportDirectory = Directory.systemTemp.createTempSync(
      'bleunlock_acceptance_empty_test_',
    );
    addTearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: const DashboardState(
                  snapshot: DashboardSnapshot.initial(),
                  devices: [],
                  logs: [],
                  config: ProximityConfig(),
                ),
                exportDirectory: exportDirectory,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('导出验收包'));
    await tester.tap(find.text('导出验收包'));
    await tester.pumpAndSettle();

    final files = exportDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();
    expect(files, hasLength(1));

    final bundle =
        jsonDecode(files.single.readAsStringSync()) as Map<String, Object?>;
    expect(bundle['schemaVersion'], 1);
    expect(bundle['logs'], isEmpty);
    expect(bundle['sessionDiagnostics'], isEmpty);
    expect(bundle['deviceDiagnostics'], isEmpty);
    expect(find.textContaining('验收包已导出：'), findsOneWidget);
  });

  testWidgets('exports acceptance bundle with config and summaries',
      (tester) async {
    final exportDirectory = Directory.systemTemp.createTempSync(
      'bleunlock_acceptance_test_',
    );
    addTearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });
    final logs = [
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 12),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        platform: 'mock',
        deviceId: 'band-1',
        rssi: -52,
        reason: 'bleAdvertisement',
        sessionState: DashboardSessionState.locked,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: DashboardState(
                  snapshot: const DashboardSnapshot(
                    monitoringStatus: 'Monitoring',
                    stateLabel: 'Locked',
                    bestRssi: -52,
                    selectedDeviceCount: 1,
                    lastActionLabel: 'Locked screen',
                    bluetoothCapabilityLabel: 'supported',
                    autoLockCapabilityLabel: 'supported',
                    wakeCapabilityLabel: 'supported',
                    autoUnlockCapabilityLabel: 'missing secret',
                    trayCapabilityLabel: 'supported',
                    startupCapabilityLabel: 'supported',
                    startupEnabled: true,
                    autoUnlockSecretConfigured: false,
                    autoUnlockSecretEditable: true,
                    autoUnlockPermissionSettingsAvailable: false,
                  ),
                  devices: [
                    DashboardDeviceView(
                      id: 'band-1',
                      idLabel: 'ID band-1',
                      name: 'Xiaomi Smart Band',
                      rssiLabel: '-52 dBm',
                      lastSeenLabel: 'Last seen 10:11:12',
                      presenceLabel: 'Close',
                      isSelected: true,
                    ),
                  ],
                  logs: logs,
                  config: const ProximityConfig(
                    unlockRssi: -55,
                    lockRssi: -82,
                    noSignalTimeout: Duration(seconds: 45),
                    lockDelay: Duration(seconds: 7),
                    wakeOnProximity: true,
                  ),
                ),
                exportDirectory: exportDirectory,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('导出验收包'));
    await tester.tap(find.text('导出验收包'));
    await tester.pumpAndSettle();

    final files = exportDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();
    expect(files, hasLength(1));
    expect(files.single.path, contains('bleunlock-acceptance-'));

    final bundle =
        jsonDecode(files.single.readAsStringSync()) as Map<String, Object?>;
    final validationSessionId = bundle['validationSessionId'] as String;
    final snapshot = bundle['snapshot'] as Map<String, Object?>;
    final environment = bundle['environment'] as Map<String, Object?>;
    final acceptanceSummary =
        bundle['acceptanceSummary'] as Map<String, Object?>;
    final config = bundle['config'] as Map<String, Object?>;
    final sessions = bundle['sessionDiagnostics'] as List<Object?>;
    final devices = bundle['devices'] as List<Object?>;
    final logsJson = bundle['logs'] as List<Object?>;

    expect(snapshot['stateLabel'], 'Locked');
    expect(validationSessionId, startsWith('validation-'));
    expect(snapshot['startupEnabled'], true);
    expect(environment['exportSource'], 'validationSection');
    expect(environment['platform'], Platform.operatingSystem);
    expect(environment['buildMode'], 'debug');
    expect(acceptanceSummary['hasScanEvidence'], true);
    expect(acceptanceSummary['hasLockedSessionScanEvidence'], true);
    expect(acceptanceSummary['selectedDeviceCount'], 1);
    expect(acceptanceSummary['requiredChecklistCount'], 15);
    expect(acceptanceSummary['completedRequiredChecklistCount'], 2);
    expect(
      acceptanceSummary['missingRequiredChecklistLabels'],
      contains('Proximity decision'),
    );
    expect(config['unlockRssi'], -55);
    expect(config['noSignalTimeoutSeconds'], 45);
    expect(sessions.single, isA<Map<String, Object?>>());
    expect(devices.single, isA<Map<String, Object?>>());
    expect(logsJson.single, isA<Map<String, Object?>>());
    expect(find.textContaining('验收包已导出：'), findsOneWidget);
  });

  testWidgets('exports validation runbook bundle', (tester) async {
    final exportDirectory = Directory.systemTemp.createTempSync(
      'bleunlock_runbook_test_',
    );
    addTearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });
    final logs = [
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 12),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
        sessionState: DashboardSessionState.locked,
      ),
      DashboardLogEntry(
        timestamp: DateTime(2026, 5, 28, 10, 11, 15),
        category: DashboardLogCategory.decision,
        message: 'Decision close',
        reason: 'close',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: DashboardState(
                  snapshot: const DashboardSnapshot(
                    monitoringStatus: 'Monitoring',
                    stateLabel: 'Locked',
                    bestRssi: -52,
                    selectedDeviceCount: 1,
                    lastActionLabel: 'Decision close',
                    bluetoothCapabilityLabel: 'supported',
                    autoLockCapabilityLabel: 'supported',
                    wakeCapabilityLabel: 'supported',
                    autoUnlockCapabilityLabel: 'supported',
                    trayCapabilityLabel: 'supported',
                    startupCapabilityLabel: 'supported',
                    startupEnabled: true,
                    autoUnlockSecretConfigured: true,
                    autoUnlockSecretEditable: true,
                    autoUnlockPermissionSettingsAvailable: false,
                  ),
                  devices: const [],
                  logs: logs,
                  config: const ProximityConfig(enableMacAutoUnlock: true),
                ),
                exportDirectory: exportDirectory,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('导出验收手册'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出验收手册'));
    await tester.pumpAndSettle();

    final files = exportDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();
    expect(files, hasLength(1));
    expect(files.single.path, contains('bleunlock-runbook-'));

    final bundle =
        jsonDecode(files.single.readAsStringSync()) as Map<String, Object?>;
    final validationSessionId = bundle['validationSessionId'] as String;
    final environment = bundle['environment'] as Map<String, Object?>;
    final acceptanceSummary =
        bundle['acceptanceSummary'] as Map<String, Object?>;
    final runbookSteps = bundle['runbookSteps'] as List<Object?>;
    final missingRunbookSteps = bundle['missingRunbookSteps'] as List<Object?>;

    expect(bundle['bundleType'], 'validationRunbook');
    expect(validationSessionId, startsWith('validation-'));
    expect(environment['exportSource'], 'validationSection');
    expect(acceptanceSummary['readyForAcceptance'], false);
    expect(runbookSteps, hasLength(5));
    expect(missingRunbookSteps, hasLength(4));
    expect(
      (runbookSteps.first as Map<String, Object?>)['action'],
      'Scan nearby selected BLE devices',
    );
    expect(
      bundle['runbookJsonLines'],
      contains('"expectedEvidence":"Real BLE scan, locked scan, decision"'),
    );
    expect(
      bundle['missingRunbookJsonLines'],
      contains('"id":"lockWake"'),
    );
    expect(
      bundle['missingRunbookJsonLines'],
      contains('"nextActionHint":"Move the selected device away'),
    );
    expect(
      bundle['missingActionList'],
      contains('Lock and wake: Move the selected device away'),
    );
    expect(find.textContaining('验收手册已导出：'), findsOneWidget);
  });

  testWidgets('exports acceptance and runbook bundles with same validation id',
      (tester) async {
    final exportDirectory = Directory.systemTemp.createTempSync(
      'bleunlock_validation_id_test_',
    );
    addTearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                state: const DashboardState(
                  snapshot: DashboardSnapshot.initial(),
                  devices: [],
                  logs: [],
                  config: ProximityConfig(),
                ),
                exportDirectory: exportDirectory,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('导出验收包'));
    await tester.tap(find.text('导出验收包'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('导出验收手册'));
    await tester.tap(find.text('导出验收手册'));
    await tester.pumpAndSettle();

    final files = exportDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList();
    expect(files, hasLength(2));

    final bundles = [
      for (final file in files)
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
    ];
    final ids = bundles
        .map((bundle) => bundle['validationSessionId'])
        .whereType<String>()
        .toSet();

    expect(ids, hasLength(1));
    expect(ids.single, startsWith('validation-'));
  });

  testWidgets('exports validation bundles with validation id in filenames',
      (tester) async {
    final exportDirectory = Directory.systemTemp.createTempSync(
      'bleunlock_validation_filename_id_test_',
    );
    addTearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                validationSessionId: 'validation-manual-001',
                state: const DashboardState(
                  snapshot: DashboardSnapshot.initial(),
                  devices: [],
                  logs: [],
                  config: ProximityConfig(),
                ),
                exportDirectory: exportDirectory,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('导出验收包'));
    await tester.tap(find.text('导出验收包'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('导出验收手册'));
    await tester.tap(find.text('导出验收手册'));
    await tester.pumpAndSettle();

    final filePaths = exportDirectory
        .listSync()
        .whereType<File>()
        .map((file) => file.path)
        .toList();

    expect(filePaths, hasLength(2));
    expect(
      filePaths,
      contains(contains('bleunlock-acceptance-validation-manual-001-')),
    );
    expect(
      filePaths,
      contains(contains('bleunlock-runbook-validation-manual-001-')),
    );
  });

  testWidgets('exports all validation evidence files in one action',
      (tester) async {
    final exportDirectory = Directory.systemTemp.createTempSync(
      'bleunlock_validation_evidence_all_test_',
    );
    addTearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                validationSessionId: 'validation-manual-001',
                state: DashboardState(
                  snapshot: const DashboardSnapshot(
                    monitoringStatus: 'Monitoring',
                    stateLabel: 'Locked',
                    bestRssi: -52,
                    selectedDeviceCount: 1,
                    lastActionLabel: 'Decision close',
                    bluetoothCapabilityLabel: 'supported',
                    autoLockCapabilityLabel: 'supported',
                    wakeCapabilityLabel: 'supported',
                    autoUnlockCapabilityLabel: 'supported',
                    trayCapabilityLabel: 'supported',
                    startupCapabilityLabel: 'supported',
                    startupEnabled: true,
                    autoUnlockSecretConfigured: true,
                    autoUnlockSecretEditable: true,
                    autoUnlockPermissionSettingsAvailable: false,
                  ),
                  devices: const [],
                  logs: [
                    DashboardLogEntry(
                      timestamp: DateTime(2026, 5, 28, 10),
                      category: DashboardLogCategory.scan,
                      message: 'Scan band-1 -52 dBm',
                      deviceId: 'band-1',
                      rssi: -52,
                      sessionState: DashboardSessionState.locked,
                    ),
                    DashboardLogEntry(
                      timestamp: DateTime(2026, 5, 28, 10, 0, 1),
                      category: DashboardLogCategory.decision,
                      message: 'Decision close',
                      reason: 'close',
                    ),
                  ],
                  config: const ProximityConfig(enableMacAutoUnlock: true),
                ),
                exportDirectory: exportDirectory,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('export-validation-evidence')),
    );
    await tester.ensureVisible(find.text('Windows 构建验证'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('gate-windowsBuild-panel')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gate-windowsBuild-panel')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('gate-windowsBuild-pass')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gate-windowsBuild-pass')));
    await tester.pump();
    expect(find.text('Windows 构建验证 已通过'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('gate-windowsBuild-result')),
      'Built on Windows 11 ARM64',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gate-windowsBuild-evidence')),
      'bleunlock-windows-build.log',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gate-windowsBuild-notes')),
      'WinRT linkage verified',
    );
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('export-validation-evidence')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('export-validation-evidence')));
    await tester.pumpAndSettle();

    final files = exportDirectory.listSync().whereType<File>().toList();
    final filePaths = files.map((file) => file.path).toList();

    expect(files, hasLength(5));
    expect(
      filePaths,
      contains(contains('bleunlock-diagnostics-validation-manual-001-')),
    );
    expect(
      filePaths,
      contains(contains('bleunlock-acceptance-validation-manual-001-')),
    );
    expect(
      filePaths,
      contains(contains('bleunlock-runbook-validation-manual-001-')),
    );
    expect(
      filePaths,
      contains(contains('bleunlock-missing-actions-validation-manual-001-')),
    );
    expect(
      filePaths,
      contains(contains('bleunlock-manifest-validation-manual-001-')),
    );

    final diagnostics = files
        .singleWhere((file) => file.path.endsWith('.jsonl'))
        .readAsStringSync();
    expect(
        diagnostics, contains('"validationSessionId":"validation-manual-001"'));
    expect(diagnostics, contains('"message":"Scan band-1 -52 dBm"'));

    final manifestFile = files.singleWhere(
      (file) => file.path.contains('bleunlock-manifest-validation-manual-001-'),
    );
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
    final manifestFiles = manifest['files'] as List<Object?>;
    final manifestFileTypes = manifestFiles
        .map((entry) => (entry as Map<String, Object?>)['type'])
        .toSet();
    expect(manifest['bundleType'], 'validationManifest');
    expect(manifest['validationSessionId'], 'validation-manual-001');
    expect(manifest['exportDirectory'], exportDirectory.path);
    expect(manifest['fileCount'], 4);
    expect(manifest['readyForAcceptance'], false);
    expect(manifest['missingRequiredEvidenceCount'], 12);
    expect(
      manifest['missingRequiredChecklistLabels'],
      contains('Auto lock action'),
    );
    expect(
      manifest['missingActionList'],
      contains('Lock and wake: Move the selected device away'),
    );
    final externalGateSummary =
        manifest['externalValidationGateSummary'] as Map<String, Object?>;
    expect(externalGateSummary['totalCount'], 6);
    expect(externalGateSummary['passedCount'], 1);
    expect(externalGateSummary['failedCount'], 0);
    expect(externalGateSummary['manualRequiredCount'], 5);
    expect(externalGateSummary['completedCount'], 1);
    expect(externalGateSummary['incompleteCount'], 5);
    expect(externalGateSummary['hasFailures'], false);
    expect(externalGateSummary['allResolved'], false);
    expect(
      externalGateSummary['pendingGateLabels'],
      contains('Real BLE scan'),
    );
    expect(manifest['overallReadyForAcceptance'], false);
    expect(manifest['overallAcceptanceBlockers'], 17);
    expect(
      manifest['overallAcceptanceBlockerLabels'],
      contains('External gate pending: Real BLE scan'),
    );
    final externalGates = manifest['externalValidationGates'] as List<Object?>;
    final externalGateLabels = externalGates
        .map((gate) => (gate as Map<String, Object?>)['label'])
        .toSet();
    expect(externalGates, hasLength(6));
    expect(externalGateLabels, contains('Windows build verification'));
    expect(externalGateLabels, contains('Real BLE scan'));
    expect(externalGateLabels, contains('Lock-screen scan continuity'));
    expect(externalGateLabels, contains('macOS Accessibility unlock'));
    expect(externalGateLabels, contains('Tray actions'));
    expect(externalGateLabels, contains('Startup at login actions'));
    final windowsBuildGate = externalGates
        .cast<Map<String, Object?>>()
        .singleWhere((gate) => gate['id'] == 'windowsBuild');
    expect(windowsBuildGate['status'], 'passed');
    expect(windowsBuildGate['result'], 'Built on Windows 11 ARM64');
    expect(windowsBuildGate['evidence'], 'bleunlock-windows-build.log');
    expect(windowsBuildGate['notes'], 'WinRT linkage verified');
    expect(
      externalGates.every(
        (gate) =>
            (gate as Map<String, Object?>)['status'] == 'manualRequired' ||
            gate['status'] == 'passed',
      ),
      isTrue,
    );
    final missingActionsFile = files.singleWhere(
      (file) => file.path
          .contains('bleunlock-missing-actions-validation-manual-001-'),
    );
    expect(
      missingActionsFile.readAsStringSync(),
      contains('1. Windows build verification\n   status: passed'),
    );
    expect(
      missingActionsFile.readAsStringSync(),
      contains('   result: Built on Windows 11 ARM64'),
    );
    expect(
      missingActionsFile.readAsStringSync(),
      contains('   evidence: bleunlock-windows-build.log'),
    );
    expect(
      missingActionsFile.readAsStringSync(),
      contains('   notes: WinRT linkage verified'),
    );
    expect(manifestFileTypes, contains('diagnostics'));
    expect(manifestFileTypes, contains('acceptance'));
    expect(manifestFileTypes, contains('runbook'));
    expect(manifestFileTypes, contains('missingActions'));
    expect(
      manifestFiles.every(
        (entry) =>
            ((entry as Map<String, Object?>)['path'] as String)
                .startsWith(exportDirectory.path) &&
            entry['validationSessionId'] == 'validation-manual-001',
      ),
      isTrue,
    );

    final bundles = [
      for (final file in files.where(
        (file) =>
            file.path.endsWith('.json') &&
            !file.path.contains('bleunlock-manifest-'),
      ))
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
    ];
    final bundleTypes =
        bundles.map((bundle) => bundle['bundleType'] ?? 'acceptance').toSet();
    expect(bundleTypes, contains('acceptance'));
    expect(bundleTypes, contains('validationRunbook'));
    expect(
      bundles.every(
        (bundle) => bundle['validationSessionId'] == 'validation-manual-001',
      ),
      isTrue,
    );
    for (final bundle in bundles) {
      expect(bundle['overallReadyForAcceptance'], false);
      expect(bundle['overallAcceptanceBlockers'], 17);
      expect(
        bundle['overallAcceptanceBlockerLabels'],
        contains('External gate pending: Real BLE scan'),
      );
      final bundleExternalSummary =
          bundle['externalValidationGateSummary'] as Map<String, Object?>;
      expect(bundleExternalSummary['passedCount'], 1);
      expect(bundleExternalSummary['manualRequiredCount'], 5);
      final bundleGates = bundle['externalValidationGates'] as List<Object?>;
      expect(bundleGates, hasLength(6));
      final bundleWindowsBuildGate = bundleGates
          .cast<Map<String, Object?>>()
          .singleWhere((gate) => gate['id'] == 'windowsBuild');
      expect(bundleWindowsBuildGate['status'], 'passed');
      expect(bundleWindowsBuildGate['result'], 'Built on Windows 11 ARM64');
      expect(bundleWindowsBuildGate['evidence'], 'bleunlock-windows-build.log');
      expect(bundleWindowsBuildGate['notes'], 'WinRT linkage verified');
    }
    final acceptanceBundle = bundles
        .singleWhere((bundle) => bundle['bundleType'] != 'validationRunbook');
    final runbookBundle = bundles.singleWhere(
      (bundle) => bundle['bundleType'] == 'validationRunbook',
    );
    expect(
      acceptanceBundle['externalValidationGates'],
      equals(runbookBundle['externalValidationGates']),
    );

    final missingActions = files
        .singleWhere((file) => file.path.endsWith('.txt'))
        .readAsStringSync();
    expect(missingActions, contains('relatedFiles:'));
    expect(
      missingActions,
      contains('  diagnostics: '
          'bleunlock-diagnostics-validation-manual-001-*.jsonl'),
    );
    expect(
      find.textContaining('验收证据已导出：'),
      findsOneWidget,
    );
  });

  testWidgets('exports missing actions as a validation scoped text file',
      (tester) async {
    final exportDirectory = Directory.systemTemp.createTempSync(
      'bleunlock_missing_actions_test_',
    );
    addTearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                validationSessionId: 'validation-manual-001',
                state: DashboardState(
                  snapshot: const DashboardSnapshot(
                    monitoringStatus: 'Monitoring',
                    stateLabel: 'Locked',
                    bestRssi: -52,
                    selectedDeviceCount: 1,
                    lastActionLabel: 'Decision close',
                    bluetoothCapabilityLabel: 'supported',
                    autoLockCapabilityLabel: 'supported',
                    wakeCapabilityLabel: 'supported',
                    autoUnlockCapabilityLabel: 'supported',
                    trayCapabilityLabel: 'supported',
                    startupCapabilityLabel: 'supported',
                    startupEnabled: true,
                    autoUnlockSecretConfigured: true,
                    autoUnlockSecretEditable: true,
                    autoUnlockPermissionSettingsAvailable: false,
                  ),
                  devices: [],
                  logs: [
                    DashboardLogEntry(
                      timestamp: DateTime(2026, 5, 28, 10),
                      category: DashboardLogCategory.scan,
                      message: 'Scan band-1 -52 dBm',
                      deviceId: 'band-1',
                      rssi: -52,
                      sessionState: DashboardSessionState.locked,
                    ),
                    DashboardLogEntry(
                      timestamp: DateTime(2026, 5, 28, 10, 0, 1),
                      category: DashboardLogCategory.decision,
                      message: 'Decision close',
                      reason: 'close',
                    ),
                  ],
                  config: const ProximityConfig(enableMacAutoUnlock: true),
                ),
                exportDirectory: exportDirectory,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('导出缺失动作'));
    await tester.tap(find.text('导出缺失动作'));
    await tester.pumpAndSettle();

    final files = exportDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.txt'))
        .toList();

    expect(files, hasLength(1));
    expect(
      files.single.path,
      contains('bleunlock-missing-actions-validation-manual-001-'),
    );
    final content = files.single.readAsStringSync();
    expect(content, contains('validationSessionId: validation-manual-001'));
    expect(content, contains('exportedAt: '));
    expect(content, contains('platform: ${Platform.operatingSystem}'));
    expect(content, contains('buildMode: debug'));
    expect(content, contains('relatedFiles:'));
    expect(content, contains('  exportDirectory: ${exportDirectory.path}'));
    expect(
      content,
      contains('  diagnostics: '
          'bleunlock-diagnostics-validation-manual-001-*.jsonl'),
    );
    expect(
      content,
      contains('  acceptance: '
          'bleunlock-acceptance-validation-manual-001-*.json'),
    );
    expect(
      content,
      contains('  runbook: '
          'bleunlock-runbook-validation-manual-001-*.json'),
    );
    expect(content, contains('missingActions:'));
    expect(
        content, contains('1. Lock and wake: Move the selected device away'));
    expect(content, contains('   result: '));
    expect(content, contains('   evidence: '));
    expect(content, contains('   notes: '));
    expect(content,
        contains('2. macOS auto unlock: Enable macOS automatic unlock'));
    expect(content, contains('externalValidationGates:'));
    expect(content, contains('1. Windows build verification'));
    expect(content, contains('   status: manualRequired'));
    expect(content, contains('   action: Run flutter build windows'));
    expect(content, contains('2. Real BLE scan'));
    expect(content, contains('3. Lock-screen scan continuity'));
    expect(content, contains('4. macOS Accessibility unlock'));
    expect(content, contains('5. Tray actions'));
    expect(content, contains('6. Startup at login actions'));
    expect(find.textContaining('缺失动作已导出：'), findsOneWidget);
  });

  testWidgets('copies checklist and runbook lines with validation id',
      (tester) async {
    var clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                validationSessionId: 'validation-manual-001',
                state: DashboardState(
                  snapshot: const DashboardSnapshot.initial(),
                  devices: const [],
                  logs: [
                    DashboardLogEntry(
                      timestamp: DateTime(2026, 5, 28, 10),
                      category: DashboardLogCategory.scan,
                      message: 'Scan band-1 -52 dBm',
                      deviceId: 'band-1',
                      rssi: -52,
                    ),
                  ],
                  config: const ProximityConfig(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('复制验收清单'));
    await tester.tap(find.text('复制验收清单'));
    await tester.pump();

    final checklistClipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(
      checklistClipboard?.text,
      contains('"validationSessionId":"validation-manual-001"'),
    );

    await tester.ensureVisible(find.text('复制验收手册'));
    await tester.tap(find.text('复制验收手册'));
    await tester.pump();

    final runbookClipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(
      runbookClipboard?.text,
      contains('"validationSessionId":"validation-manual-001"'),
    );

    await tester.ensureVisible(find.text('复制外部门禁'));
    await tester.tap(find.text('复制外部门禁'));
    await tester.pump();

    final gatesClipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final gateLines = gatesClipboard!.text!
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    expect(gateLines, hasLength(6));
    final firstGate = jsonDecode(gateLines.first) as Map<String, Object?>;
    expect(firstGate['validationSessionId'], 'validation-manual-001');
    expect(firstGate['id'], 'windowsBuild');
    expect(firstGate['status'], 'manualRequired');
  });

  testWidgets('copies one external gate with manual evidence', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    var clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                validationSessionId: 'validation-manual-001',
                state: DashboardState(
                  snapshot: const DashboardSnapshot.initial(),
                  devices: const [],
                  logs: const [],
                  config: const ProximityConfig(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('gate-windowsBuild-panel')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('gate-windowsBuild-panel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('gate-windowsBuild-pass')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('gate-windowsBuild-result')),
      'Windows debug build completed',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gate-windowsBuild-evidence')),
      'logs/windows-build-2026-05-31.txt',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gate-windowsBuild-notes')),
      'Verified on Windows 11 laptop',
    );

    await tester.tap(find.byKey(const ValueKey('gate-windowsBuild-copy')));
    await tester.pump();

    final gateClipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final gateJson = jsonDecode(gateClipboard!.text!) as Map<String, Object?>;
    expect(gateJson['validationSessionId'], 'validation-manual-001');
    expect(gateJson['id'], 'windowsBuild');
    expect(gateJson['label'], 'Windows build verification');
    expect(gateJson['status'], 'passed');
    expect(gateJson['action'], contains('flutter build windows'));
    expect(gateJson['result'], 'Windows debug build completed');
    expect(gateJson['evidence'], 'logs/windows-build-2026-05-31.txt');
    expect(gateJson['notes'], 'Verified on Windows 11 laptop');
  });

  testWidgets('exports one external gate evidence file', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    var clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final exportDirectory = Directory.systemTemp.createTempSync(
      'bleunlock_external_gate_export_test_',
    );
    addTearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ValidationSection(
                validationSessionId: 'validation-manual-001',
                state: DashboardState(
                  snapshot: const DashboardSnapshot.initial(),
                  devices: const [],
                  logs: const [],
                  config: const ProximityConfig(),
                ),
                exportDirectory: exportDirectory,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('gate-windowsBuild-panel')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('gate-windowsBuild-panel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('gate-windowsBuild-pass')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('gate-windowsBuild-result')),
      'Windows debug build completed',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gate-windowsBuild-evidence')),
      'logs/windows-build-2026-05-31.txt',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gate-windowsBuild-notes')),
      'Verified on Windows 11 laptop',
    );

    await tester.tap(find.byKey(const ValueKey('gate-windowsBuild-export')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('gate-realBleScan-panel')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('gate-realBleScan-panel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('gate-realBleScan-pass')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('gate-realBleScan-result')),
      'Band advertisements captured',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gate-realBleScan-evidence')),
      'logs/real-ble-scan-2026-05-31.jsonl',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gate-realBleScan-notes')),
      'Xiaomi Smart Band observed at -52 dBm',
    );

    await tester.tap(find.byKey(const ValueKey('gate-realBleScan-export')));
    await tester.pumpAndSettle();

    final files = exportDirectory.listSync().whereType<File>().toList();
    expect(files, hasLength(4));
    final windowsGateFile = files.singleWhere(
      (file) => file.path.contains(
        'bleunlock-external-gate-validation-manual-001-windowsBuild-',
      ),
    );
    final realBleScanGateFile = files.singleWhere(
      (file) => file.path.contains(
        'bleunlock-external-gate-validation-manual-001-realBleScan-',
      ),
    );
    final indexFiles = files
        .where(
          (file) => file.path.contains(
            'bleunlock-external-gate-index-validation-manual-001-',
          ),
        )
        .toList(growable: false);
    expect(indexFiles, hasLength(2));
    indexFiles.sort((left, right) => left.path.compareTo(right.path));
    final latestIndexFile = indexFiles.last;
    expect(
      realBleScanGateFile.path,
      contains('bleunlock-external-gate-validation-manual-001-realBleScan-'),
    );
    expect(
      windowsGateFile.path,
      contains('bleunlock-external-gate-validation-manual-001-windowsBuild-'),
    );

    final gateJson =
        jsonDecode(windowsGateFile.readAsStringSync()) as Map<String, Object?>;
    expect(gateJson['schemaVersion'], 1);
    expect(gateJson['bundleType'], 'externalValidationGate');
    expect(gateJson['validationSessionId'], 'validation-manual-001');
    expect(gateJson['exportedAt'], isA<String>());
    final environment = gateJson['environment'] as Map<String, Object?>;
    expect(environment['exportSource'], 'validationSection');
    expect(environment['platform'], isA<String>());
    expect(environment['buildMode'], isA<String>());
    expect(gateJson['id'], 'windowsBuild');
    expect(gateJson['label'], 'Windows build verification');
    expect(gateJson['status'], 'passed');
    expect(gateJson['action'], contains('flutter build windows'));
    expect(gateJson['result'], 'Windows debug build completed');
    expect(gateJson['evidence'], 'logs/windows-build-2026-05-31.txt');
    expect(gateJson['notes'], 'Verified on Windows 11 laptop');
    final indexJson =
        jsonDecode(latestIndexFile.readAsStringSync()) as Map<String, Object?>;
    expect(indexJson['schemaVersion'], 1);
    expect(indexJson['bundleType'], 'externalValidationGateIndex');
    expect(indexJson['validationSessionId'], 'validation-manual-001');
    expect(indexJson['exportedAt'], isA<String>());
    final indexEnvironment = indexJson['environment'] as Map<String, Object?>;
    expect(indexEnvironment['exportSource'], 'validationSection');
    expect(indexEnvironment['platform'], isA<String>());
    expect(indexEnvironment['buildMode'], isA<String>());
    expect(indexJson['fileCount'], 2);
    final indexEntries = indexJson['files'] as List<Object?>;
    expect(indexEntries, hasLength(2));
    final entries = indexEntries.cast<Map<String, Object?>>();
    final windowsEntry = entries.singleWhere(
      (entry) => entry['gateId'] == 'windowsBuild',
    );
    final scanEntry = entries.singleWhere(
      (entry) => entry['gateId'] == 'realBleScan',
    );
    expect(windowsEntry['type'], 'externalValidationGate');
    expect(windowsEntry['gateLabel'], 'Windows build verification');
    expect(windowsEntry['status'], 'passed');
    expect(windowsEntry['validationSessionId'], 'validation-manual-001');
    expect(
      windowsEntry['path'].toString().replaceAll('/', '\\'),
      windowsGateFile.path.replaceAll('/', '\\'),
    );
    expect(windowsEntry['filename'], windowsGateFile.uri.pathSegments.last);
    expect(scanEntry['type'], 'externalValidationGate');
    expect(scanEntry['gateLabel'], 'Real BLE scan');
    expect(scanEntry['status'], 'passed');
    expect(scanEntry['validationSessionId'], 'validation-manual-001');
    expect(
      scanEntry['path'].toString().replaceAll('/', '\\'),
      realBleScanGateFile.path.replaceAll('/', '\\'),
    );
    expect(scanEntry['filename'], realBleScanGateFile.uri.pathSegments.last);

    await tester.dragUntilVisible(
      find.text('复制最新门禁索引'),
      find.byType(Scrollable).first,
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制最新门禁索引'));
    await tester.pump();

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final copiedIndex = jsonDecode(clipboard!.text!) as Map<String, Object?>;
    expect(copiedIndex['bundleType'], 'externalValidationGateIndex');
    expect(copiedIndex['validationSessionId'], 'validation-manual-001');
    expect(copiedIndex['fileCount'], 2);
    final copiedEntries = copiedIndex['files'] as List<Object?>;
    expect(
      copiedEntries
          .cast<Map<String, Object?>>()
          .map((entry) => entry['gateId'])
          .toSet(),
      containsAll(['windowsBuild', 'realBleScan']),
    );

    await tester.tap(find.text('导出最新门禁索引'));
    await tester.pumpAndSettle();

    final updatedFiles = exportDirectory.listSync().whereType<File>().toList();
    final updatedIndexFiles = updatedFiles
        .where(
          (file) => file.path.contains(
            'bleunlock-external-gate-index-validation-manual-001-',
          ),
        )
        .toList(growable: false);
    expect(updatedIndexFiles, hasLength(3));
    updatedIndexFiles.sort((left, right) => left.path.compareTo(right.path));
    final exportedIndex = jsonDecode(
      updatedIndexFiles.last.readAsStringSync(),
    ) as Map<String, Object?>;
    expect(exportedIndex['bundleType'], 'externalValidationGateIndex');
    expect(exportedIndex['validationSessionId'], 'validation-manual-001');
    expect(exportedIndex['fileCount'], 2);
    final exportedEntries = exportedIndex['files'] as List<Object?>;
    expect(
      exportedEntries
          .cast<Map<String, Object?>>()
          .map((entry) => entry['gateId'])
          .toSet(),
      containsAll(['windowsBuild', 'realBleScan']),
    );
    expect(find.textContaining('外部门禁已导出：'), findsOneWidget);
  });

  testWidgets('home page log tab is no longer scoped to validation sessions',
      (tester) async {
    final platform = MockBleunlockPlatform(
      unlockCapability: const CapabilityStatus.unsupported(),
    );
    final coordinator = AppCoordinator(platform: platform);

    await _pumpHomePage(tester, coordinator);
    await coordinator.startScanning();
    platform.emitScan(
      BleScanEvent(
        deviceId: 'band-1',
        rssi: -52,
        seenAt: DateTime(2026, 5, 28, 10),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('日志'));
    await tester.pumpAndSettle();
    final logs = tester.widget<LogSection>(
      find.byType(LogSection),
    );

    expect(find.text('验收'), findsNothing);
    expect(logs.logs, isNotEmpty);

    await _disposeCoordinator(tester, coordinator);
  });
}

Future<void> _pumpHomePage(
  WidgetTester tester,
  AppCoordinator coordinator,
) async {
  await tester.pumpWidget(
    MaterialApp(home: BLEUnlockHomePage(coordinator: coordinator)),
  );
}

Future<void> _pumpDeviceSectionInWidth(
  WidgetTester tester, {
  required double width,
  required List<DashboardDeviceView> devices,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 760);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 760,
          child: SingleChildScrollView(
            child: DeviceSection(
              devices: devices,
              isMonitoring: true,
              onStartScanning: () {},
              onRefreshDevices: () {},
              onStartMonitoring: () {},
              onPauseScanning: () {},
              onDeviceSelectionChanged: (_, __) {},
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _disposeCoordinator(
  WidgetTester tester,
  AppCoordinator coordinator,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await coordinator.dispose();
}

double _visualOrder(Offset position) {
  return position.dy * 10000 + position.dx;
}
