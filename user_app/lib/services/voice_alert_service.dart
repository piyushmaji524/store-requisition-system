import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceAlertService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;

  static const String prefVoiceAlerts = 'voice_alerts_enabled';
  static const String prefLoudAlarmMode = 'loud_alarm_mode_enabled';

  /// Initialize TTS Engine
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Configure Hindi or Indian English voice
      final languages = await _flutterTts.getLanguages;
      if (languages is List && languages.contains('hi-IN')) {
        await _flutterTts.setLanguage('hi-IN');
      } else if (languages is List && languages.contains('en-IN')) {
        await _flutterTts.setLanguage('en-IN');
      }

      await _flutterTts.setSpeechRate(0.42); // Calm, relaxed and crystal clear
      await _flutterTts.setPitch(1.15);      // Elegant, natural female pitch
      await _flutterTts.setVolume(1.0);      // Max loudness

      // Auto-select premium Indian female voice if installed
      try {
        final voices = await _flutterTts.getVoices;
        if (voices is List) {
          for (final v in voices) {
            if (v is Map) {
              final name = v['name']?.toString().toLowerCase() ?? '';
              final locale = v['locale']?.toString() ?? '';
              if ((locale.startsWith('hi') || locale.contains('IN')) &&
                  (name.contains('female') || name.contains('hie') || name.contains('cfl') || name.contains('woman'))) {
                await _flutterTts.setVoice({'name': v['name'], 'locale': v['locale']});
                debugPrint('[VoiceAlert] Selected female voice: ${v['name']}');
                break;
              }
            }
          }
        }
      } catch (_) {}

      // Set audio attributes to bypass silent when playing alert
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        ],
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('[VoiceAlert] TTS Init error: $e');
    }
  }

  /// Check if Voice Announcement is enabled (Defaults to ON)
  static Future<bool> isVoiceAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefVoiceAlerts) ?? true;
  }

  /// Toggle Voice Announcement
  static Future<void> setVoiceAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefVoiceAlerts, enabled);
  }

  /// Check if Loud Alarm Mode (Bypass Silent) is enabled (Defaults to ON)
  static Future<bool> isLoudAlarmModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefLoudAlarmMode) ?? true;
  }

  /// Toggle Loud Alarm Mode
  static Future<void> setLoudAlarmModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefLoudAlarmMode, enabled);
  }

  /// Speak text out loud through mobile speaker
  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    final voiceEnabled = await isVoiceAlertsEnabled();
    if (!voiceEnabled) return;

    try {
      await init();

      final loudMode = await isLoudAlarmModeEnabled();
      if (loudMode) {
        // Boost volume to max so it's heard clearly
        await _flutterTts.setVolume(1.0);
      }

      await _flutterTts.stop(); // Stop any previous speech
      await _flutterTts.speak(text);
      debugPrint('[VoiceAlert] Spoke: "$text"');
    } catch (e) {
      debugPrint('[VoiceAlert] Error speaking: $e');
    }
  }

  /// Test voice sample for settings preview
  static Future<void> testVoice() async {
    await speak('Store se aapka 20 Bag Cement issue ho gaya hai, kripya counter se collect kar lein.');
  }

  /// Stop ongoing speech
  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
