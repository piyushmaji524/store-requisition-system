import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_alert_service.dart';

class OneSignalNotificationService {
  // Configured OneSignal App ID for Store Terminal App
  static const String appId = '5aaf748f-c68e-4c92-87c4-bf23e9e93a41';

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _verificationDialogShown = false;
  static VoidCallback? onNotificationReceived;

  /// Centralized SDK Initialization
  static Future<void> init() async {
    try {
      // 1. Initialize OneSignal SDK
      OneSignal.initialize(appId);

      // Request notification permission immediately
      OneSignal.Notifications.requestPermission(true);

      // Initialize Voice Alert Engine
      await VoiceAlertService.init();

      // 2. Foreground Notification Listener (Speaks voice alert on receipt & triggers live feed sync)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        final notif = event.notification;
        final data = notif.additionalData;
        final voiceText = data?['voice_text'] ?? 'Material request received hua hai';
        if (voiceText.toString().trim().isNotEmpty) {
          VoiceAlertService.speak(voiceText.toString());
        }
        onNotificationReceived?.call();
      });

      // 3. Notification Click Handler
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('[OneSignal] Notification clicked: ${event.notification.title}');
        VoiceAlertService.stop();
      });

      // 4. Setup Push Subscription Observer for Verification Dialog
      _setupSubscriptionObserver();
    } catch (e) {
      debugPrint('[OneSignal] Initialization error: $e');
    }
  }

  /// Push Subscription Observer to confirm server-assigned registration
  static void _setupSubscriptionObserver() {
    final initialId = OneSignal.User.pushSubscription.id;
    if (_isValidSubscriptionId(initialId)) {
      _checkAndShowVerificationDialog();
    }

    OneSignal.User.pushSubscription.addObserver((state) {
      final currentId = state.current.id;
      if (_isValidSubscriptionId(currentId)) {
        _checkAndShowVerificationDialog();
      }
    });
  }

  /// Check if the subscription ID is server-assigned
  static bool _isValidSubscriptionId(String? id) {
    if (id == null || id.isEmpty) return false;
    if (id.toLowerCase().startsWith('local-')) return false;
    return true;
  }

  /// Check shared preferences and display verification modal once
  static Future<void> _checkAndShowVerificationDialog() async {
    if (_verificationDialogShown) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('onesignal_verification_dialog_shown') ?? false;

    if (!alreadyShown) {
      _verificationDialogShown = true;
      await prefs.setBool('onesignal_verification_dialog_shown', true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIntegrationCompleteDialog();
      });
    }
  }

  /// Display verification dialog
  static void _showIntegrationCompleteDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Your OneSignal SDK integration is complete!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: const Text(
            'You can now send Push Notifications & In-App Messages through OneSignal. Tap below to enable push notifications.',
            style: TextStyle(fontSize: 14),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                OneSignal.Notifications.requestPermission(true);
              },
            ),
          ],
        );
      },
    );
  }

  /// Associate device with Store Keeper user ID
  static Future<void> login(String userId) async {
    try {
      await OneSignal.login(userId);
      await OneSignal.User.addTagWithKey('role', 'STORE_USER');
      debugPrint('[OneSignal] Logged in as Store Keeper User ID: $userId');
    } catch (e) {
      debugPrint('[OneSignal] Login error: $e');
    }
  }

  /// Disassociate device upon logout
  static Future<void> logout() async {
    try {
      await OneSignal.logout();
      debugPrint('[OneSignal] Logged out from OneSignal.');
    } catch (e) {
      debugPrint('[OneSignal] Logout error: $e');
    }
  }
}
