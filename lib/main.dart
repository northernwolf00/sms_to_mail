import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'models/app_settings.dart';
import 'screens/home_screen.dart';
import 'services/permission_service.dart';
import 'services/service_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required by flutter_foreground_task so the main isolate and the task
  // isolate can communicate.
  FlutterForegroundTask.initCommunicationPort();

  // Configure the foreground service (channel, repeat interval, boot behaviour).
  ServiceController.initForegroundTask();

  runApp(const SmsForwarderApp());
}

class SmsForwarderApp extends StatelessWidget {
  const SmsForwarderApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap in WithForegroundTask so the service stays bound while UI is alive.
    return MaterialApp(
      title: 'SMS to Gmail',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const WithForegroundTask(child: Bootstrap()),
    );
  }
}

/// Handles first-launch permission flow, then shows the Home screen.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final granted = await PermissionService.smsGranted;
    if (!granted && mounted) {
      await _showRationale();
    }

    // Register the SMS listener (incl. background handler) on every launch.
    ServiceController.registerSmsListener();

    // If the user previously enabled the service, make sure it's running.
    final settings = await AppSettings.load();
    if (settings.serviceEnabled) {
      await ServiceController.start();
    }

    if (mounted) setState(() => _ready = true);
  }

  Future<void> _showRationale() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissions needed'),
        content: const Text(
          'This app forwards every incoming SMS to your Gmail.\n\n'
          'It needs:\n'
          '• SMS access — to read incoming messages\n'
          '• Notifications — for the background service notice\n'
          '• Battery-optimization exemption — so it keeps running\n\n'
          'All processing is on-device; messages are sent only to the '
          'email you configure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    await PermissionService.requestAll();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const HomeScreen();
  }
}
