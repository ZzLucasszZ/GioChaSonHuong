package com.example.order_inventory_app

import android.media.AudioManager
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.order_inventory_app/audio"

    // Save volumes for all streams that might produce the STT beep
    private var savedMusic: Int = -1
    private var savedNotification: Int = -1
    private var savedSystem: Int = -1
    private var savedRing: Int = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val am = getSystemService(AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "muteBeep" -> {
                        // Save and mute all streams that could produce the STT beep
                        savedMusic = am.getStreamVolume(AudioManager.STREAM_MUSIC)
                        savedNotification = am.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
                        savedSystem = am.getStreamVolume(AudioManager.STREAM_SYSTEM)
                        savedRing = am.getStreamVolume(AudioManager.STREAM_RING)

                        am.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
                        am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)
                        am.setStreamVolume(AudioManager.STREAM_SYSTEM, 0, 0)
                        am.setStreamVolume(AudioManager.STREAM_RING, 0, 0)

                        result.success(true)
                    }
                    "unmuteBeep" -> {
                        if (savedMusic >= 0) {
                            am.setStreamVolume(AudioManager.STREAM_MUSIC, savedMusic, 0)
                            am.setStreamVolume(AudioManager.STREAM_NOTIFICATION, savedNotification, 0)
                            am.setStreamVolume(AudioManager.STREAM_SYSTEM, savedSystem, 0)
                            am.setStreamVolume(AudioManager.STREAM_RING, savedRing, 0)
                            savedMusic = -1
                            savedNotification = -1
                            savedSystem = -1
                            savedRing = -1
                        }
                        result.success(true)
                    }
                    "cancelVibration" -> {
                        try {
                            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val vm = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
                                vm.defaultVibrator
                            } else {
                                @Suppress("DEPRECATION")
                                getSystemService(VIBRATOR_SERVICE) as Vibrator
                            }
                            vibrator.cancel()
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
