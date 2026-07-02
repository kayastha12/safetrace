import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/config_service.dart';
import 'services/database_service.dart';
import 'services/firebase_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations (portrait only)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system navigation overlay styling for premium feel
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A10),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize services
  await ConfigService.init();
  await DatabaseService.init();
  await FirebaseService.init();

  runApp(const SafeTraceApp());
}

class SafeTraceApp extends StatefulWidget {
  const SafeTraceApp({super.key});

  @override
  State<SafeTraceApp> createState() => _SafeTraceAppState();
}

class _SafeTraceAppState extends State<SafeTraceApp> with WidgetsBindingObserver {
  bool _isFirstLaunch = true;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLockStatus();
    }
  }

  Future<void> _checkLockStatus() async {
    // Reload configurations and check lock status
    await ConfigService.reload();
    setState(() {
      _isFirstLaunch = ConfigService.isFirstLaunch;
      _isLocked = ConfigService.isAppLocked && ConfigService.securityPin.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeTrace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A10),
        primaryColor: Colors.blueAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.cyanAccent,
          surface: Color(0xFF161622),
          error: Colors.redAccent,
        ),
      ),
      home: _isFirstLaunch
          ? const OnboardingScreen()
          : (_isLocked
              ? LockScreen(
                  onUnlocked: () {
                    setState(() => _isLocked = false);
                  },
                )
              : const DashboardScreen()),
    );
  }
}
