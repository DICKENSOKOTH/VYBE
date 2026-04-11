// lib/features/player/mini_player.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/providers.dart';
import '../../core/theme/vybe_colors.dart';
import '../../core/dynamic_palette_notifier.dart';
import '../../widgets/glassmorphic_card.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track    = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(isPlayingProvider);
    final progress  = ref.watch(playbackProgressProvider);
    final engine    = ref.read(audioEngineProvider);
    final palette   = ref.watch(dynamicPaletteProvider).valueOrNull
        ?? DynamicPalette.fallback;

    // Extract local song id for artwork
    final songId = track.isLocal
        ? int.tryParse(track.id.replaceFirst('local_', ''))
        : null;

    return GestureDetector(
      onTap: () => ref.read(playerExpandedProvider.notifier).state = true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        height: 72,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: VybeColors.surfaceElevated.withAlpha(230),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.vibrant.withAlpha(70), width: 0.8),
              ),
              child: Stack(children: [
                // Progress bar
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(palette.vibrant),
                      minHeight: 2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    // Artwork
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: VybeColors.vybeGradient,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: songId != null
                            ? QueryArtworkWidget(
                                id: songId, type: ArtworkType.AUDIO,
                                artworkBorder: BorderRadius.zero,
                                artworkFit: BoxFit.cover,
                                nullArtworkWidget: _DefaultArt())
                            : _DefaultArt(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'VybeSans', fontSize: 14,
                              fontWeight: FontWeight.w600, color: VybeColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(track.artist,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'VybeSans',
                              fontSize: 12, color: VybeColors.textTertiary)),
                      ],
                    )),
                    if (isPlaying) ...[
                      const WaveformBars(isPlaying: true, height: 18, barCount: 4,
                          barWidth: 2.5, barSpacing: 1.5),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: engine.togglePlayPause,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: VybeColors.textPrimary, size: 28)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: engine.skipNext,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.skip_next_rounded,
                            color: VybeColors.textSecondary, size: 24)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: VybeColors.vybeGradient),
    child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 20));
}
