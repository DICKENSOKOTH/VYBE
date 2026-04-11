// android/app/src/main/kotlin/com/vybe/app/BitPerfectChannel.kt
package com.vybe.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioMixerAttributes
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * VYBE Bit-Perfect Platform Channel
 *
 * Exposes Android 14+ AudioMixerAttributes.MIXER_BEHAVIOR_BIT_PERFECT to Flutter.
 * This requests exclusive control of a USB DAC from the Android audio mixer,
 * bypassing the system mixer completely — raw PCM goes directly to the DAC.
 *
 * Channel: com.vybe.app/bit_perfect
 */
class BitPerfectChannel(
    private val context: Context,
    private val messenger: io.flutter.plugin.common.BinaryMessenger
) {
    companion object {
        private const val CHANNEL_NAME = "com.vybe.app/bit_perfect"
        private const val TAG = "VYBE_BitPerfect"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported"        -> result.success(isSupported())
                "enableBitPerfect"   -> enableBitPerfect(result)
                "disableBitPerfect"  -> result.success(disableBitPerfect())
                "getUsbDacInfo"      -> result.success(getUsbDacInfo())
                "getNativeSampleRate"-> result.success(getNativeSampleRate())
                else                 -> result.notImplemented()
            }
        }
        Log.d(TAG, "BitPerfect channel registered. API level: ${Build.VERSION.SDK_INT}")
    }

    private fun isSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE // API 34

    private fun buildMediaAudioAttributes(): AudioAttributes =
        AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

    /**
     * Request bit-perfect mixing mode from the audio mixer.
     *
     * Correct Android 14 API:
     *   AudioManager.setPreferredMixerAttributes(
     *       AudioAttributes, portId: Int, AudioMixerAttributes)
     */
    private fun enableBitPerfect(result: MethodChannel.Result) {
        if (!isSupported()) {
            result.error(
                "UNSUPPORTED",
                "Bit-Perfect requires Android 14+. Current API: ${Build.VERSION.SDK_INT}",
                null
            )
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Find connected USB DAC — bit-perfect only makes sense on external DACs
                val usbDevice = audioManager
                    .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    .firstOrNull { d ->
                        d.type == android.media.AudioDeviceInfo.TYPE_USB_DEVICE ||
                        d.type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET ||
                        d.type == android.media.AudioDeviceInfo.TYPE_USB_ACCESSORY
                    }

                if (usbDevice == null) {
                    result.error("NO_USB_DAC", "No USB DAC connected", null)
                    return
                }

                // Build AudioFormat directly — do NOT go through AudioTrack
                val audioFormat = AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_32BIT)
                    .setSampleRate(getNativeSampleRate())
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build()

                // Build AudioMixerAttributes — constructor takes AudioFormat, not AudioTrack
                val mixerAttributes = AudioMixerAttributes.Builder(audioFormat)
                    .setMixerBehavior(AudioMixerAttributes.MIXER_BEHAVIOR_BIT_PERFECT)
                    .build()

                // setPreferredMixerAttributes(AudioAttributes, portId, AudioMixerAttributes)
                audioManager.setPreferredMixerAttributes(
                    buildMediaAudioAttributes(),
                    usbDevice,
                    mixerAttributes
                )

                Log.d(TAG, "Bit-Perfect mode ENABLED ✓ on device: ${usbDevice.productName}")
                result.success(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enable Bit-Perfect: ${e.message}")
            result.error("BIT_PERFECT_FAILED", e.message, null)
        }
    }

    /**
     * Restore default mixer behavior.
     *
     * Correct Android 14 API:
     *   AudioManager.clearPreferredMixerAttributes(AudioAttributes, portId: Int)
     */
    private fun disableBitPerfect(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val usbDevice = audioManager
                    .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    .firstOrNull { d ->
                        d.type == android.media.AudioDeviceInfo.TYPE_USB_DEVICE ||
                        d.type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET ||
                        d.type == android.media.AudioDeviceInfo.TYPE_USB_ACCESSORY
                    }

                if (usbDevice != null) {
                    // clearPreferredMixerAttributes(AudioAttributes, portId)
                    audioManager.clearPreferredMixerAttributes(
                        buildMediaAudioAttributes(),
                        usbDevice
                    )
                    Log.d(TAG, "Bit-Perfect mode DISABLED")
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to disable Bit-Perfect: ${e.message}")
            false
        }
    }

    private fun getUsbDacInfo(): Map<String, Any>? {
        val usbDevice = audioManager
            .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .firstOrNull { d ->
                d.type == android.media.AudioDeviceInfo.TYPE_USB_DEVICE ||
                d.type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET ||
                d.type == android.media.AudioDeviceInfo.TYPE_USB_ACCESSORY
            } ?: run {
                Log.d(TAG, "No USB DAC detected")
                return null
            }

        val maxSampleRate = usbDevice.sampleRates.maxOrNull() ?: 48000
        val maxChannels   = usbDevice.channelCounts.maxOrNull() ?: 2

        return mapOf(
            "productName"      to (usbDevice.productName?.toString() ?: "USB Audio Device"),
            "type"             to usbDevice.type,
            "id"               to usbDevice.id,
            "maxSampleRate"    to maxSampleRate,
            "maxChannels"      to maxChannels,
            "supportsBitPerfect" to isSupported(),
            "sampleRates"      to usbDevice.sampleRates.toList(),
        ).also { Log.d(TAG, "USB DAC: ${it["productName"]} @ ${maxSampleRate}Hz") }
    }

    private fun getNativeSampleRate(): Int {
        return audioManager
            .getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
            ?.toIntOrNull() ?: 48000
    }
}