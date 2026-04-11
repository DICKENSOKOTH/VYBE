// android/app/src/main/kotlin/com/vybe/app/HiResAudioChannel.kt
package com.vybe.app

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * VYBE Hi-Res Audio Platform Channel — Tier B
 *
 * Detects the device's native audio capabilities so Flutter can decide
 * which playback tier to activate:
 *
 *   Tier A — Standard (any device)
 *   Tier B — Hi-Res (Android 8+, native sample rate > 48kHz or 24-bit support)
 *   Tier C — Bit-Perfect (Android 14+, USB DAC) ← handled by BitPerfectChannel
 *
 * The key insight: Android's default AudioTrack resamples everything to 48kHz
 * unless you explicitly set the native sample rate. VYBE detects this and
 * requests the correct rate — same technique used by UAPP, Neutron, Poweramp.
 *
 * Channel: com.vybe.app/hi_res_audio
 */
class HiResAudioChannel(
    private val context: Context,
    private val messenger: BinaryMessenger
) {
    companion object {
        private const val CHANNEL_NAME = "com.vybe.app/hi_res_audio"
        private const val TAG = "VYBE_HiRes"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceCapabilities" -> result.success(getDeviceCapabilities())
                "getNativeSampleRate" -> result.success(getNativeSampleRate())
                "getNativeFramesPerBuffer" -> result.success(getNativeFramesPerBuffer())
                "supportsHiRes" -> result.success(supportsHiRes())
                "getRecommendedTier" -> result.success(getRecommendedTier())
                else -> result.notImplemented()
            }
        }
        Log.d(TAG, "HiRes channel registered")
    }

    /**
     * Full device audio capability map — sent to Flutter on startup.
     * Flutter uses this to set the initial playback tier.
     */
    private fun getDeviceCapabilities(): Map<String, Any> {
        val nativeSampleRate = getNativeSampleRate()
        val framesPerBuffer = getNativeFramesPerBuffer()
        val hiResSupported = supportsHiRes()
        val outputDevices = getOutputDeviceInfo()

        val capabilities = mapOf(
            "nativeSampleRate" to nativeSampleRate,
            "framesPerBuffer" to framesPerBuffer,
            "hiResSupported" to hiResSupported,
            "apiLevel" to Build.VERSION.SDK_INT,
            "bitPerfectSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE),
            "outputDevices" to outputDevices,
            "recommendedTier" to getRecommendedTier(),
        )

        Log.d(TAG, "Device capabilities: sampleRate=$nativeSampleRate, " +
            "hiRes=$hiResSupported, API=${Build.VERSION.SDK_INT}")

        return capabilities
    }

    /**
     * The device's native output sample rate.
     * This is what Android's audio hardware actually runs at.
     * Feeding audio at this rate avoids the Android resampler.
     */
    private fun getNativeSampleRate(): Int {
        return audioManager
            .getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
            ?.toIntOrNull()
            ?: 48000 // Fallback to Android default
    }

    /**
     * The device's native frames per buffer — used for low-latency audio.
     * just_audio can use this for buffer size optimization.
     */
    private fun getNativeFramesPerBuffer(): Int {
        return audioManager
            .getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)
            ?.toIntOrNull()
            ?: 256
    }

    /**
     * True if device natively supports Hi-Res audio output.
     * Criteria:
     *   - Native sample rate > 48000 (96kHz, 192kHz etc.)
     *   - OR: Android 8+ with Pro Audio feature (PROPERTY_SUPPORT_MIC_NEAR_ULTRASOUND)
     *   - OR: USB DAC with hi-res capability connected
     */
    private fun supportsHiRes(): Boolean {
        val nativeSampleRate = getNativeSampleRate()
        if (nativeSampleRate > 48000) return true

        // Check for professional audio support (low-latency, hi-res capable)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val proAudio = context.packageManager
                .hasSystemFeature("android.hardware.audio.pro")
            if (proAudio) return true
        }

        // Check output devices for hi-res capable hardware
        val outputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return outputDevices.any { device ->
            val deviceMaxRate = device.sampleRates.maxOrNull() ?: 0
            deviceMaxRate > 48000
        }
    }

    /**
     * Get info about all active output audio devices.
     */
    private fun getOutputDeviceInfo(): List<Map<String, Any>> {
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return devices.map { device ->
            mapOf(
                "id" to device.id,
                "type" to device.type,
                "productName" to (device.productName?.toString() ?: ""),
                "maxSampleRate" to (device.sampleRates.maxOrNull() ?: 0),
                "sampleRates" to device.sampleRates.toList(),
                "channelCounts" to device.channelCounts.toList(),
            )
        }
    }

    /**
     * Determine which playback tier the device should use:
     *   0 = Standard (Tier A)
     *   1 = HiRes    (Tier B)
     *   2 = BitPerfect (Tier C) — only if USB DAC connected
     *
     * BitPerfect isn't set here — it's activated by user action or
     * DAC detection popup. This just reports the maximum achievable tier.
     */
    private fun getRecommendedTier(): Int {
        // Check for USB DAC (Bit-Perfect candidate)
        val hasUsbDac = audioManager
            .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .any { device ->
                device.type == android.media.AudioDeviceInfo.TYPE_USB_DEVICE ||
                device.type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET
            }

        if (hasUsbDac && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return 2 // Bit-Perfect candidate
        }

        if (supportsHiRes() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return 1 // Hi-Res
        }

        return 0 // Standard
    }
}
