import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'models/app_settings.dart';
import 'screens/home_screen.dart';
import 'services/permission_service.dart';
import 'services/service_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  FlutterForegroundTask.initCommunicationPort();
  ServiceController.initForegroundTask();
  runApp(const SmsForwarderApp());
}

class SmsForwarderApp extends StatelessWidget {
  const SmsForwarderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS to Gmail',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const WithForegroundTask(child: Bootstrap()),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: brightness,
        primary: const Color(0xFF6C63FF),
        secondary: const Color(0xFF03DAC6),
      ),
      fontFamily: 'Roboto',
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5FF),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF3A3A5E)
                : const Color(0xFFDDDDFF),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFFF6B6B), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: TextStyle(
          color: isDark
              ? const Color(0xFF9090B0)
              : const Color(0xFF6060A0),
        ),
        prefixIconColor: const Color(0xFF6C63FF),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6C63FF),
          side: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            isDark ? const Color(0xFF2A2A4E) : const Color(0xFF1A1A2E),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark
              ? const Color(0xFF6060A0)
              : const Color(0xFFB0B0D0);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF6C63FF);
          }
          return isDark
              ? const Color(0xFF2A2A4E)
              : const Color(0xFFDDDDFF);
        }),
      ),
    );
  }
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap>
    with SingleTickerProviderStateMixin {
  bool _ready = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Show the rationale (and request) if SMS *or* the phone/call-log
    // permission is still missing — covers upgrades that add call forwarding.
    final smsOk = await PermissionService.smsGranted;
    final callOk = await PermissionService.callLogGranted;
    if ((!smsOk || !callOk) && mounted) await _showRationale();
    ServiceController.registerSmsListener();
    final settings = await AppSettings.load();
    if (settings.serviceEnabled) await ServiceController.start();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _showRationale() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.security_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Permissions Needed',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'To forward your SMS and calls to Gmail, this app needs a few permissions:',
                style: TextStyle(fontSize: 14, color: Color(0xFF9090B0)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _permRow(Icons.sms_rounded, 'SMS access',
                  'Read incoming messages'),
              const SizedBox(height: 10),
              _permRow(Icons.call_rounded, 'Phone & call log',
                  'Detect incoming & missed calls'),
              const SizedBox(height: 10),
              _permRow(Icons.notifications_rounded, 'Notifications',
                  'Background service notice'),
              const SizedBox(height: 10),
              _permRow(Icons.battery_charging_full_rounded,
                  'Battery optimization', 'Keep running in background'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Grant Permissions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await PermissionService.requestAll();
  }

  Widget _permRow(IconData icon, String title, String sub) => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(sub,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9090B0))),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF3D35C8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.forward_to_inbox_rounded,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  'SMS to Gmail',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Starting up…',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const Spacer(flex: 3),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      );
    }
    return const HomeScreen();
  }
}
