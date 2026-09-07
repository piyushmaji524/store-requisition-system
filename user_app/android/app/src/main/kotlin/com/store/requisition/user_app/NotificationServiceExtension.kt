package com.store.requisition.user_app

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.util.Log
import androidx.annotation.Keep
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension
import java.util.Locale

@Keep
class NotificationServiceExtension : INotificationServiceExtension {
    companion object {
        private const val TAG = "VoiceAlertServiceExt"
        private var ttsInstance: TextToSpeech? = null
        private var isTtsInitialized = false
    }

    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val context = event.context
        val notif = event.notification
        val data = notif.additionalData

        val voiceText = if (data != null && data.has("voice_text")) {
            data.optString("voice_text", notif.body ?: "")
        } else {
            notif.body ?: ""
        }

        Log.d(TAG, "Notification received in background! Voice text: $voiceText")

        if (!voiceText.isNullOrBlank()) {
            speakVoice(context, voiceText)
        }
    }

    private fun speakVoice(context: Context, text: String) {
        try {
            // Check user preferences saved by Flutter SharedPreferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val voiceEnabled = prefs.getBoolean("flutter.voice_alerts_enabled", true)
            if (!voiceEnabled) {
                Log.d(TAG, "Voice alerts disabled in user settings, skipping speech.")
                return
            }

            val loudMode = prefs.getBoolean("flutter.loud_alarm_mode_enabled", true)

            Handler(Looper.getMainLooper()).post {
                if (loudMode) {
                    try {
                        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        val maxVol = audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
                        audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, maxVol, 0)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to adjust volume: ${e.message}")
                    }
                }

                if (ttsInstance == null || !isTtsInitialized) {
                    ttsInstance = TextToSpeech(context.applicationContext) { status ->
                        if (status == TextToSpeech.SUCCESS) {
                            isTtsInitialized = true
                            val langRes = ttsInstance?.setLanguage(Locale("hi", "IN"))
                            if (langRes == TextToSpeech.LANG_MISSING_DATA || langRes == TextToSpeech.LANG_NOT_SUPPORTED) {
                                ttsInstance?.setLanguage(Locale("en", "IN"))
                            }

                            // Select female voice if available on this Android device
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                    val voices = ttsInstance?.voices
                                    val femaleVoice = voices?.firstOrNull { v ->
                                        val vName = v.name.lowercase()
                                        (v.locale.language == "hi" || v.locale.country == "IN") &&
                                        (vName.contains("female") || vName.contains("hie") || vName.contains("cfl") || vName.contains("woman"))
                                    }
                                    if (femaleVoice != null) {
                                        ttsInstance?.voice = femaleVoice
                                        Log.d(TAG, "Selected native female voice: ${femaleVoice.name}")
                                    }
                                }
                            } catch (e: Exception) {
                                Log.w(TAG, "Voice selection fallback: ${e.message}")
                            }

                            ttsInstance?.setPitch(1.15f)     // Natural, pleasant female pitch
                            ttsInstance?.setSpeechRate(0.78f) // Calm, relaxed pacing (clear and slow)
                            executeSpeak(text)
                        } else {
                            Log.e(TAG, "TextToSpeech init failed with status: $status")
                        }
                    }
                } else {
                    executeSpeak(text)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception in speakVoice: ${e.message}", e)
        }
    }

    private fun executeSpeak(text: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val params = Bundle()
                params.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_MUSIC)
                ttsInstance?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "STORE_TTS_ID_${System.currentTimeMillis()}")
            } else {
                val params = HashMap<String, String>()
                params[TextToSpeech.Engine.KEY_PARAM_STREAM] = AudioManager.STREAM_MUSIC.toString()
                ttsInstance?.speak(text, TextToSpeech.QUEUE_FLUSH, params)
            }
            Log.d(TAG, "TTS speak executed successfully for: $text")
        } catch (e: Exception) {
            Log.e(TAG, "TTS speak execution failed: ${e.message}")
        }
    }
}
