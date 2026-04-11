// android/app/src/main/kotlin/com/vybe/app/AudioEffectsChannel.kt
package com.vybe.app

import android.content.Context
import android.media.audiofx.BassBoost
import android.media.audiofx.EnvironmentalReverb
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.PresetReverb
import android.media.audiofx.Virtualizer
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * VYBE Audio Effects Platform Channel
 *
 * Exposes Android AudioEffect API to Flutter:
 *   - BassBoost       → hardware-accelerated shelf filter
 *   - Virtualizer     → 3D surround / stereo widening (Haas-style)
 *   - LoudnessEnhancer → volume normalization / loudness compensation
 *
 * Channel: com.vybe.app/audio_effects
 *
 * Note: These effects are attached to the global audio session (sessionId = 0)
 * which applies to all audio output on the device. When just_audio's built-in
 * AndroidEqualizer is active, these effects work alongside it in the chain.
 *
 * In Bit-Perfect mode, Flutter calls disableAll() before switching to
 * MIXER_BEHAVIOR_BIT_PERFECT — this is enforced from the Dart side.
 */
class AudioEffectsChannel(
    private val context: Context,
    private val messenger: BinaryMessenger
) {
    companion object {
        private const val CHANNEL_NAME = "com.vybe.app/audio_effects"
        private const val TAG = "VYBE_AudioFX"
        private const val SESSION_ID = 0 // Global session — affects all audio
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null

    fun register() {
        initEffects()

        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    // ── Bass Boost ─────────────────────────────────────
                    "setBassBoostEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        bassBoost?.enabled = enabled
                        Log.d(TAG, "BassBoost ${if (enabled) "ON" else "OFF"}")
                        result.success(null)
                    }
                    "setBassBoostStrength" -> {
                        // strength: 0–1000 (short)
                        val strength = (call.argument<Double>("strength") ?: 0.0)
                            .toInt()
                            .coerceIn(0, 1000)
                            .toShort()
                        bassBoost?.setStrength(strength)
                        Log.d(TAG, "BassBoost strength: $strength")
                        result.success(null)
                    }
                    "getBassBoostStrength" -> {
                        result.success(bassBoost?.roundedStrength?.toInt() ?: 0)
                    }

                    // ── 3D Surround / Virtualizer ─────────────────────
                    "setVirtualizerEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        virtualizer?.enabled = enabled
                        Log.d(TAG, "Virtualizer (3D Surround) ${if (enabled) "ON" else "OFF"}")
                        result.success(null)
                    }
                    "setVirtualizerStrength" -> {
                        val strength = (call.argument<Double>("strength") ?: 0.0)
                            .toInt()
                            .coerceIn(0, 1000)
                            .toShort()
                        virtualizer?.setStrength(strength)
                        result.success(null)
                    }
                    "getVirtualizerStrength" -> {
                        result.success(virtualizer?.roundedStrength?.toInt() ?: 0)
                    }
                    "isVirtualizationSupported" -> {
                        result.success(virtualizer?.strengthSupported ?: false)
                    }

                    // ── Loudness Enhancer (Normalization) ─────────────
                    "setLoudnessEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        loudnessEnhancer?.enabled = enabled
                        result.success(null)
                    }
                    "setLoudnessGain" -> {
                        // gain in millibels (1000 = +1 dB)
                        val gainMb = (call.argument<Double>("gainMb") ?: 0.0).toFloat()
                        loudnessEnhancer?.setTargetGain(gainMb.toInt())
                        result.success(null)
                    }

                    // ── Global ────────────────────────────────────────
                    "disableAll" -> {
                        bassBoost?.enabled = false
                        virtualizer?.enabled = false
                        loudnessEnhancer?.enabled = false
                        Log.d(TAG, "All effects DISABLED (Bit-Perfect mode)")
                        result.success(null)
                    }
                    "getEffectsState" -> {
                        result.success(mapOf(
                            "bassBoostEnabled" to (bassBoost?.enabled ?: false),
                            "bassBoostStrength" to (bassBoost?.roundedStrength?.toInt() ?: 0),
                            "virtualizerEnabled" to (virtualizer?.enabled ?: false),
                            "virtualizerStrength" to (virtualizer?.roundedStrength?.toInt() ?: 0),
                            "loudnessEnabled" to (loudnessEnhancer?.enabled ?: false),
                        ))
                    }
                    "reinitialize" -> {
                        releaseEffects()
                        initEffects()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "AudioEffects error [${call.method}]: ${e.message}")
                result.error("AUDIO_FX_ERROR", e.message, null)
            }
        }

        Log.d(TAG, "AudioEffects channel registered")
    }

    private fun initEffects() {
        try {
            bassBoost = BassBoost(0, SESSION_ID).apply {
                enabled = false
            }
        } catch (e: Exception) {
            Log.w(TAG, "BassBoost unavailable: ${e.message}")
        }

        try {
            virtualizer = Virtualizer(0, SESSION_ID).apply {
                enabled = false
            }
        } catch (e: Exception) {
            Log.w(TAG, "Virtualizer unavailable: ${e.message}")
        }

        try {
            loudnessEnhancer = LoudnessEnhancer(SESSION_ID).apply {
                enabled = false
            }
        } catch (e: Exception) {
            Log.w(TAG, "LoudnessEnhancer unavailable: ${e.message}")
        }

        Log.d(TAG, "Effects initialized — BassBoost: ${bassBoost != null}, " +
            "Virtualizer: ${virtualizer != null}, " +
            "LoudnessEnhancer: ${loudnessEnhancer != null}")
    }

    private fun releaseEffects() {
        bassBoost?.release()
        bassBoost = null
        virtualizer?.release()
        virtualizer = null
        loudnessEnhancer?.release()
        loudnessEnhancer = null
    }
}
