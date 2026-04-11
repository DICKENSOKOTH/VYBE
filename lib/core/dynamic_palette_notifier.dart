// lib/core/dynamic_palette_notifier.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'providers.dart';

class DynamicPalette {
  /// Darkened vibrant (25% HSL lightness) — background tint overlay.
  final Color tint;
  /// Full vibrant — glow, progress bar, border accent.
  final Color vibrant;

  const DynamicPalette({required this.tint, required this.vibrant});

  static const fallback = DynamicPalette(
    tint:    Color(0xFF1A0A2E),
    vibrant: Color(0xFFFF1B6B),
  );
}

class DynamicPaletteNotifier extends AsyncNotifier<DynamicPalette> {
  static final _cache = <String, DynamicPalette>{};
  static const _maxCacheSize = 30;

  @override
  Future<DynamicPalette> build() async {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return DynamicPalette.fallback;
    final cached = _cache[track.id];
    if (cached != null) return cached;
    final palette = await _extract(track);
    if (_cache.length >= _maxCacheSize) _cache.remove(_cache.keys.first);
    _cache[track.id] = palette;
    return palette;
  }

  Future<DynamicPalette> _extract(dynamic track) async {
    ui.Image? uiImage;

    if (track.albumArtUri != null && (track.albumArtUri as String).isNotEmpty) {
      uiImage = await _loadNetworkImage(track.albumArtUri as String);
    }

    if (uiImage == null && (track.isLocal as bool)) {
      final rawId = (track.id as String).replaceFirst('local_', '');
      final songId = int.tryParse(rawId);
      if (songId != null) {
        try {
          final bytes = await OnAudioQuery().queryArtwork(
            songId, ArtworkType.AUDIO, size: 150, quality: 50,
          );
          if (bytes != null && bytes.isNotEmpty) {
            uiImage = await _decodeBytes(bytes);
          }
        } catch (_) {}
      }
    }

    if (uiImage == null) return DynamicPalette.fallback;

    try {
      final pg = await PaletteGenerator.fromImage(uiImage, maximumColorCount: 16);
      final vibrant = pg.lightVibrantColor?.color
          ?? pg.vibrantColor?.color
          ?? pg.lightMutedColor?.color
          ?? pg.dominantColor?.color
          ?? DynamicPalette.fallback.vibrant;
      final tint = _setLightness(vibrant, 0.25);
      return DynamicPalette(tint: tint, vibrant: vibrant);
    } catch (_) {
      return DynamicPalette.fallback;
    }
  }

  Future<ui.Image?> _loadNetworkImage(String url) async {
    try {
      final stream    = NetworkImage(url).resolve(ImageConfiguration.empty);
      final completer = Completer<ui.Image?>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (_, __) {
          if (!completer.isCompleted) completer.complete(null);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      return await completer.future.timeout(const Duration(seconds: 8), onTimeout: () {
        stream.removeListener(listener);
        return null;
      });
    } catch (_) { return null; }
  }

  Future<ui.Image?> _decodeBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 150, targetHeight: 150);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) { return null; }
  }

  Color _setLightness(Color c, double lightness) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * 1.15).clamp(0.0, 1.0))
        .withLightness(lightness)
        .toColor();
  }
}
