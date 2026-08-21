import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/level/calibration.dart';
import 'src/level/gravity_source.dart';
import 'src/level/host_bridge.dart';
import 'src/level/level_controller.dart';
import 'src/ui/level_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A level that re-orients while it is being tilted is unreadable.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const BubbleLevelApp());
}

class BubbleLevelApp extends StatefulWidget {
  const BubbleLevelApp({super.key});

  @override
  State<BubbleLevelApp> createState() => _BubbleLevelAppState();
}

class _BubbleLevelAppState extends State<BubbleLevelApp>
    with WidgetsBindingObserver {
  static const HostBridge _host = HostBridge();

  final LevelController _controller = LevelController(
    source: PlatformGravitySource(),
    store: const PlatformCalibrationStore(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.start());
    unawaited(_host.setKeepScreenOn(true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_host.setKeepScreenOn(false));
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The screen is only held awake while the level is actually on screen.
    unawaited(_host.setKeepScreenOn(state == AppLifecycleState.resumed));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrueLevel',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DDC84),
          brightness: Brightness.dark,
        ),
      ),
      home: LevelPage(controller: _controller),
    );
  }
}
