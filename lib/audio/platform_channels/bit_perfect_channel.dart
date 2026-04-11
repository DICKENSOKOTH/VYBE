// lib/audio/platform_channels/bit_perfect_channel.dart
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Flutter-side wrapper for the Android Bit-Perfect platform channel.
/// Communicates with BitPerfectChannel.kt
class BitPerfectChannel {
  static const _channel = MethodChannel('com.vybe.app/bit_perfect');

  /// Check if the device supports bit-perfect mode (Android 14+)
  static Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (e) {
      debugPrint('[BitPerfect] isSupported error: $e');
      return false;
    }
  }

  /// Enable bit-perfect mode — requests exclusive DAC control
  static Future<bool> enable() async {
    try {
      return await _channel.invokeMethod<bool>('enableBitPerfect') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BitPerfect] Enable failed: ${e.message}');
      return false;
    }
  }

  /// Restore default mixer behavior
  static Future<bool> disable() async {
    try {
      return await _channel.invokeMethod<bool>('disableBitPerfect') ?? false;
    } catch (e) {
      debugPrint('[BitPerfect] Disable failed: $e');
      return false;
    }
  }

  /// Returns USB DAC info map, or null if no DAC connected
  static Future<UsbDacInfo?> getUsbDacInfo() async {
    try {
      final result = await _channel.invokeMethod<Map>('getUsbDacInfo');
      if (result == null) return null;
      return UsbDacInfo.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      debugPrint('[BitPerfect] getUsbDacInfo error: $e');
      return null;
    }
  }

  static Future<int> getNativeSampleRate() async {
    try {
      return await _channel.invokeMethod<int>('getNativeSampleRate') ?? 48000;
    } catch (_) {
      return 48000;
    }
  }
}

class UsbDacInfo {
  final String productName;
  final int maxSampleRate;
  final int maxChannels;
  final bool supportsBitPerfect;
  final List<int> sampleRates;

  const UsbDacInfo({
    required this.productName,
    required this.maxSampleRate,
    required this.maxChannels,
    required this.supportsBitPerfect,
    required this.sampleRates,
  });

  factory UsbDacInfo.fromMap(Map<String, dynamic> map) {
    return UsbDacInfo(
      productName: map['productName'] as String? ?? 'USB Audio Device',
      maxSampleRate: map['maxSampleRate'] as int? ?? 48000,
      maxChannels: map['maxChannels'] as int? ?? 2,
      supportsBitPerfect: map['supportsBitPerfect'] as bool? ?? false,
      sampleRates:
          (map['sampleRates'] as List?)?.cast<int>() ?? const [44100, 48000],
    );
  }
}

// ─── Audio Effects Channel ─────────────────────────────────────────────────────

/// Flutter-side wrapper for AudioEffectsChannel.kt
class AudioEffectsChannel {
  static const _channel = MethodChannel('com.vybe.app/audio_effects');

  // ── Bass Boost ────────────────────────────────────────────────────────────
  static Future<void> setBassBoostEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setBassBoostEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('[AudioFX] setBassBoostEnabled error: $e');
    }
  }

  /// strength: 0.0–1.0 (mapped to 0–1000 internally)
  static Future<void> setBassBoostStrength(double strength) async {
    try {
      await _channel.invokeMethod(
        'setBassBoostStrength',
        {'strength': (strength * 1000).clamp(0, 1000)},
      );
    } catch (e) {
      debugPrint('[AudioFX] setBassBoostStrength error: $e');
    }
  }

  // ── 3D Surround / Virtualizer ─────────────────────────────────────────────
  static Future<void> setVirtualizerEnabled(bool enabled) async {
    try {
      await _channel
          .invokeMethod('setVirtualizerEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('[AudioFX] setVirtualizerEnabled error: $e');
    }
  }

  static Future<void> setVirtualizerStrength(double strength) async {
    try {
      await _channel.invokeMethod(
        'setVirtualizerStrength',
        {'strength': (strength * 1000).clamp(0, 1000)},
      );
    } catch (e) {
      debugPrint('[AudioFX] setVirtualizerStrength error: $e');
    }
  }

  // ── Loudness Enhancer ─────────────────────────────────────────────────────
  static Future<void> setLoudnessEnabled(bool enabled) async {
    try {
      await _channel
          .invokeMethod('setLoudnessEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('[AudioFX] setLoudnessEnabled error: $e');
    }
  }

  /// gainDb: target gain in dB (converted to millibels: x1000)
  static Future<void> setLoudnessGain(double gainDb) async {
    try {
      await _channel.invokeMethod(
        'setLoudnessGain',
        {'gainMb': gainDb * 1000},
      );
    } catch (e) {
      debugPrint('[AudioFX] setLoudnessGain error: $e');
    }
  }

  // ── Global ────────────────────────────────────────────────────────────────
  static Future<void> disableAll() async {
    try {
      await _channel.invokeMethod('disableAll');
    } catch (e) {
      debugPrint('[AudioFX] disableAll error: $e');
    }
  }

  static Future<Map<String, dynamic>> getEffectsState() async {
    try {
      final result = await _channel.invokeMethod<Map>('getEffectsState');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('[AudioFX] getEffectsState error: $e');
      return {};
    }
  }
}

// ─── Hi-Res Audio Channel ─────────────────────────────────────────────────────

/// Flutter-side wrapper for HiResAudioChannel.kt
class HiResAudioChannel {
  static const _channel = MethodChannel('com.vybe.app/hi_res_audio');

  static Future<DeviceAudioCapabilities> getDeviceCapabilities() async {
    try {
      final result = await _channel.invokeMethod<Map>('getDeviceCapabilities');
      return DeviceAudioCapabilities.fromMap(
        Map<String, dynamic>.from(result ?? {}),
      );
    } catch (e) {
      debugPrint('[HiRes] getDeviceCapabilities error: $e');
      return DeviceAudioCapabilities.standard();
    }
  }

  static Future<int> getRecommendedTier() async {
    try {
      return await _channel.invokeMethod<int>('getRecommendedTier') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

class DeviceAudioCapabilities {
  final int nativeSampleRate;
  final int framesPerBuffer;
  final bool hiResSupported;
  final bool bitPerfectSupported;
  final int apiLevel;
  final int recommendedTier;

  const DeviceAudioCapabilities({
    required this.nativeSampleRate,
    required this.framesPerBuffer,
    required this.hiResSupported,
    required this.bitPerfectSupported,
    required this.apiLevel,
    required this.recommendedTier,
  });

  factory DeviceAudioCapabilities.fromMap(Map<String, dynamic> map) {
    return DeviceAudioCapabilities(
      nativeSampleRate: map['nativeSampleRate'] as int? ?? 48000,
      framesPerBuffer: map['framesPerBuffer'] as int? ?? 256,
      hiResSupported: map['hiResSupported'] as bool? ?? false,
      bitPerfectSupported: map['bitPerfectSupported'] as bool? ?? false,
      apiLevel: map['apiLevel'] as int? ?? 0,
      recommendedTier: map['recommendedTier'] as int? ?? 0,
    );
  }

  factory DeviceAudioCapabilities.standard() {
    return const DeviceAudioCapabilities(
      nativeSampleRate: 48000,
      framesPerBuffer: 256,
      hiResSupported: false,
      bitPerfectSupported: false,
      apiLevel: 0,
      recommendedTier: 0,
    );
  }
}
