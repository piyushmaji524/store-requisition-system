import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_alert_service.dart';

class OneSignalNotificationService {
  // Configured OneSignal App ID
  static const String appId = '9f4a068d-b14b-464d-82ba-1c94b448cbf5';

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _verificationDialogShown = false;

  /// Centralized SDK Initialization
  static Future<void> init() async {
    try {
      // 1. Initialize OneSignal SDK
      OneSignal.initialize(appId);

      // Initialize Voice Alert Engine
      await VoiceAlertService.init();

      // 2. Foreground Notification Listener (Speaks voice alert on receipt)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        final notif = event.notification;
        final data = notif.additionalData;
        final voiceText = data?['voice_text'] ?? notif.body ?? '';
        if (voiceText.toString().trim().isNotEmpty) {
          VoiceAlertService.speak(voiceText.toString());
        }
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
    // Immediate evaluation of current subscription state
    final initialId = OneSignal.User.pushSubscription.id;
    if (_isValidSubscriptionId(initialId)) {
      _checkAndShowVerificationDialog();
    }

    // Retained observer for changes
    OneSignal.User.pushSubscription.addObserver((state) {
      final currentId = state.current.id;
      if (_isValidSubscriptionId(currentId)) {
        _checkAndShowVerificationDialog();
      }
    });
  }

  static bool _isValidSubscriptionId(String? id) {
    return id != null && id.isNotEmpty && !id.startsWith('local-');
  }

  /// Show the official integration verification dialog exactly once
  static Future<void> _checkAndShowVerificationDialog() async {
    if (_verificationDialogShown) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('onesignal_verification_dialog_shown') ?? false;
    if (alreadyShown) {
      _verificationDialogShown = true;
      return;
    }

    _verificationDialogShown = true;
    await prefs.setBool('onesignal_verification_dialog_shown', true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        _showVerificationDialog(context);
      }
    });
  }

  static void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Your OneSignal SDK integration is complete!'),
        content: const Text(
          'You can now send Push Notifications & In-App Messages through OneSignal. Tap below to enable push notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Request push permission strictly on button tap
              await OneSignal.Notifications.requestPermission(true);
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Map device to logged-in User ID (Strict 1-to-1 targeting)
  static Future<void> login(String userId) async {
    try {
      await OneSignal.login(userId);
      debugPrint('[OneSignal] Device mapped to User ID: $userId');
    } catch (e) {
      debugPrint('[OneSignal] Error linking user: $e');
    }
  }

  /// Unlink device when user signs out
  static Future<void> logout() async {
    try {
      await OneSignal.logout();
      debugPrint('[OneSignal] Device unlinked on logout.');
    } catch (e) {
      debugPrint('[OneSignal] Error during logout: $e');
    }
  }
}
