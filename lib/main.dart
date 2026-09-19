import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'player/player_controller.dart';
import 'services/open_file_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Show UI immediately. Heavy plugin/window setup happens after the first frame
  // so a black native window can't sit forever if something stalls.
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  PlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      await windowManager.ensureInitialized();
      const options = WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(800, 480),
        center: true,
        title: 'Fik Player',
        titleBarStyle: TitleBarStyle.normal,
        skipTaskbar: false,
      );
      await windowManager.waitUntilReadyToShow(options);
      await windowManager.show();
      await windowManager.focus();

      await OpenFileService.initialize();

      final controller = PlayerController();
      await controller.loadPreferences();

      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);

      // Open media after the real UI is on screen.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          var launchFiles = await OpenFileService.takeLaunchFiles();
          if (launchFiles.isEmpty && !OpenFileService.openedExternally) {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            launchFiles = await OpenFileService.takeLaunchFiles();
          }

          if (launchFiles.isNotEmpty) {
            await controller.openPaths(launchFiles);
          } else if (!OpenFileService.openedExternally) {
            await controller.restoreLastFolder();
          }
        } catch (e, st) {
          debugPrint('Startup media open failed: $e\n$st');
        }
      });
    } catch (e, st) {
      debugPrint('Bootstrap failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to start:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white54),
                SizedBox(height: 16),
                Text(
                  'Starting Fik Player…',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FikPlayerApp(controller: controller);
  }
}
