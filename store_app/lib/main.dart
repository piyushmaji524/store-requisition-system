import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_nav_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/onesignal_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize OneSignal Push Notification SDK
  await OneSignalNotificationService.init();

  // Check stored session
  final isLoggedIn = await ApiService.restoreSession();

  runApp(StoreApp(isLoggedIn: isLoggedIn));
}

class StoreApp extends StatelessWidget {
  final bool isLoggedIn;
  const StoreApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Store Manager',
      debugShowCheckedModeBanner: false,
      navigatorKey: OneSignalNotificationService.navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF38BDF8),
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: isLoggedIn ? const HomeNavScreen() : const LoginScreen(),
    );
  }
}
