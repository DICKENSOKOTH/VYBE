// lib/features/library/artist_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/providers.dart';
import '../../core/theme/vybe_colors.dart';
import '../../data/models/track.dart';
import 'library_screen.dart';

class ArtistDetailScreen extends ConsumerWidget {
  final ArtistModel artist;
  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(localTracksProvider);

    return Scaffold(
      backgroundColor: VybeColors.background,
      body: songsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(VybeColors.vybeStart))),
        error: (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: VybeColors.textTertiary))),
        data: (allSongs) {
          // Filter by artist name (case-insensitive)
          final artistSongs = allSongs
              .where((s) =>
                  (s.artist ?? '').toLowerCase() == artist.artist.toLowerCase())
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));

          Track toTrack(SongModel s) => Track(
                id: 'local_${s.id}',
                title: s.title,
                artist: s.artist ?? 'Unknown',
                album: s.album ?? '',
                localPath: s.uri,
                durationMs: s.duration ?? 0,
                sourceType: TrackSource.local.name,
              );

          return CustomScrollView(
            slivers: [
              // ── App bar with gradient + large artist initial ─────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: VybeColors.background,
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 48, // Increased touch target size
                    height: 48,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VybeColors.surfaceGlass,
                      shape: BoxShape.circle,
                      border: Border.all(color: VybeColors.border),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: VybeColors.textPrimary, size: 18),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    // Gradient background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            VybeColors.vybeDeep.withAlpha(180),
                            VybeColors.vybeStart.withAlpha(60),
                            VybeColors.background,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    // Large artist initial as background texture
                    Center(
                      child: Text(
                        artist.artist.isNotEmpty
                            ? artist.artist[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontFamily: 'VybeDisplay',
                          fontSize: 120,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withAlpha(30),
                          letterSpacing: -4,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Artist info + play buttons ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(artist.artist,
                          style: const TextStyle(
                              fontFamily: 'VybeDisplay',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: VybeColors.textPrimary,
                              letterSpacing: -0.4)),
                      const SizedBox(height: 4),
                      Text('${artistSongs.length} songs',
                          style: const TextStyle(
                              fontFamily: 'VybeSans',
                              fontSize: 13,
                              color: VybeColors.textSecondary)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              if (artistSongs.isEmpty) return;
                              await ref
                                  .read(audioEngineProvider)
                                  .loadQueue(artistSongs.map(toTrack).toList());
                              ref.read(playerExpandedProvider.notifier).state =
                                  true;
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: VybeColors.vybeGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Play All',
                                      style: TextStyle(
                                          fontFamily: 'VybeSans',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            if (artistSongs.isEmpty) return;
                            final engine = ref.read(audioEngineProvider);
                            // FIX: load queue first so the track is live before
                            // expanding the player — same root cause as the album
                            // shuffle black screen bug. toggleShuffle() before
                            // loadQueue() reshuffles the old playlist, then
                            // _playlist.clear() emits null currentIndex, track
                            // becomes null, NowPlayingScreen renders invisible,
                            // Navigator.pop() leaves a black screen.
                            await engine
                                .loadQueue(artistSongs.map(toTrack).toList());
                            // Explicitly enable shuffle only if currently off —
                            // never accidentally toggle it off on a second tap.
                            if (!engine.currentState.shuffleEnabled) {
                              await engine.toggleShuffle();
                            }
                            ref.read(playerExpandedProvider.notifier).state =
                                true;
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: VybeColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: VybeColors.border),
                            ),
                            child: const Icon(Icons.shuffle_rounded,
                                color: VybeColors.textSecondary, size: 20),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),

              // ── Track list ─────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final s = artistSongs[i];
                      final cur = ref.watch(currentTrackProvider);
                      final isCur = cur?.id == 'local_${s.id}';
                      return GestureDetector(
                        onTap: () async {
                          await ref.read(audioEngineProvider).loadQueue(
                              artistSongs.map(toTrack).toList(),
                              startIndex: i);
                          ref.read(playerExpandedProvider.notifier).state =
                              true;
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isCur
                                ? VybeColors.vybeStart.withAlpha(16)
                                : Colors.transparent,
                          ),
                          child: Row(children: [
                            // Track number / index
                            SizedBox(
                              width: 28,
                              child: Text('${i + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'VybeSans',
                                      fontSize: 13,
                                      color: isCur
                                          ? VybeColors.vybeStart
                                          : VybeColors.textTertiary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontFamily: 'VybeSans',
                                          fontSize: 14,
                                          fontWeight: isCur
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isCur
                                              ? VybeColors.vybeStart
                                              : VybeColors.textPrimary)),
                                  if (s.album != null && s.album!.isNotEmpty)
                                    Text(s.album!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'VybeSans',
                                            fontSize: 12,
                                            color: VybeColors.textTertiary)),
                                ],
                              ),
                            ),
                            Text(_fmt(s.duration),
                                style: const TextStyle(
                                    fontFamily: 'VybeSans',
                                    fontSize: 12,
                                    color: VybeColors.textTertiary)),
                          ]),
                        ),
                      );
                    },
                    childCount: artistSongs.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(int? ms) {
    if (ms == null) return '--:--';
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
