import 'dart:async';
import 'dart:ui' as ui;

import 'package:bleunlock_app/src/controllers/app_coordinator.dart';
import 'package:bleunlock_app/src/home_page.dart';
import 'package:bleunlock_app/src/platforms/default_platform_factory.dart';
import 'package:flutter/material.dart';

class BLEUnlockApp extends StatefulWidget {
  const BLEUnlockApp({super.key, this.coordinator});

  final AppCoordinator? coordinator;

  @override
  State<BLEUnlockApp> createState() => _BLEUnlockAppState();
}

class _BLEUnlockAppState extends State<BLEUnlockApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppCoordinator _coordinator = widget.coordinator ??
      AppCoordinator(
        platform: const DefaultBleunlockPlatformFactory().create(),
      );
  late final bool _ownsCoordinator = widget.coordinator == null;
  StreamSubscription<AppCommand>? _commandSubscription;

  @override
  void initState() {
    super.initState();
    _commandSubscription = _coordinator.commands.listen(_handleAppCommand);
    _coordinator.initialize();
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    if (_ownsCoordinator) {
      _coordinator.dispose();
    }
    super.dispose();
  }

  void _handleAppCommand(AppCommand command) {
    switch (command.kind) {
      case AppCommandKind.openSettings:
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        unawaited(_coordinator.refreshSystemSettings());
        break;
      case AppCommandKind.quit:
        unawaited(
          WidgetsBinding.instance.exitApplication(ui.AppExitType.required),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'BLEUnlock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: BLEUnlockHomePage(coordinator: _coordinator),
    );
  }
}
