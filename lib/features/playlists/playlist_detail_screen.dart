// lib/features/playlists/playlist_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/providers.dart';
import '../../core/theme/vybe_colors.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../library/library_screen.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final VybePlaylist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  /// Local mirror of the playlist's trackId list.
  ///
  /// Updated synchronously in [setState] when the user dismisses a track,
  /// BEFORE the async Hive write fires. This satisfies Flutter's Dismissible
  /// contract: the widget must be gone from the tree by the next frame after
  /// onDismissed fires — otherwise the "dismissed widget still in tree" red
  /// screen is thrown.
  late List<String> _trackIds;

  @override
  void initState() {
    super.initState();
    _trackIds = List.from(widget.playlist.trackIds);
  }

  /// Re-sync _trackIds when the playlist changes externally (e.g. a song was
  /// added from the library screen while this screen is in the back-stack).
  /// We only apply external changes — we never overwrite mid-dismissal edits.
  void _syncFromLive(VybePlaylist? live) {
    if (live == null) return;
    // Only sync if the live list is longer (additions from outside).
    // Removals are handled locally and already reflected in _trackIds.
    if (live.trackIds.length > _trackIds.length) {
      setState(() => _trackIds = List.from(live.trackIds));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch live playlist so we see external additions (e.g. from library
    // long-press context menu) without requiring a screen rebuild.
    final playlistsAsync = ref.watch(playlistsProvider);
    final livePlaylist = playlistsAsync.valueOrNull?.firstWhere(
      (p) => p.id == widget.playlist.id,
      orElse: () => widget.playlist,
    );

    // Sync once per build only when external additions appear.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFromLive(livePlaylist);
    });

    final songsAsync = ref.watch(localTracksProvider);

    return Scaffold(
      backgroundColor: VybeColors.background,
      body: SafeArea(
        child: songsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(VybeColors.vybeStart))),
          error: (e, _) => Center(
              child: Text(e.toString(),
                  style:
                      const TextStyle(color: VybeColors.textTertiary))),
          data: (allSongs) {
            // Build a fast lookup: "local_<id>" → SongModel
            final trackMap = <String, SongModel>{
              for (final s in allSongs) 'local_${s.id}': s,
            };

            // Resolve _trackIds against the actual song library, preserving
            // playlist order.  Stale IDs (deleted files) are silently dropped.
            final songs = _trackIds
                .map((id) => trackMap[id])
                .whereType<SongModel>()
                .toList();

            Track toTrack(SongModel s) => Track(
                  id: 'local_${s.id}',
                  title: s.title,
                  artist: s.artist ?? 'Unknown',
                  album: s.album ?? '',
                  localPath: s.uri,
                  durationMs: s.duration ?? 0,
                  sourceType: TrackSource.local.name,
                );

            return Column(children: [
              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: VybeColors.surfaceGlass,
                        shape: BoxShape.circle,
                        border: Border.all(color: VybeColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: VybeColors.textPrimary, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            livePlaylist?.name ?? widget.playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'VybeDisplay',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: VybeColors.textPrimary),
                          ),
                          Text('${songs.length} songs',
                              style: const TextStyle(
                                  fontFamily: 'VybeSans',
                                  fontSize: 12,
                                  color: VybeColors.textTertiary)),
                        ]),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // ── Play / Shuffle row ─────────────────────────────────────────
              if (songs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await ref
                              .read(audioEngineProvider)
                              .loadQueue(songs.map(toTrack).toList());
                          ref.read(playerExpandedProvider.notifier).state =
                              true;
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: VybeColors.vybeGradient,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Play All',
                                    style: TextStyle(
                                        fontFamily: 'VybeSans',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        final engine = ref.read(audioEngineProvider);
                        await engine.toggleShuffle();
                        await engine
                            .loadQueue(songs.map(toTrack).toList());
                        ref.read(playerExpandedProvider.notifier).state =
                            true;
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: VybeColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(11),
                          border:
                              Border.all(color: VybeColors.border),
                        ),
                        child: const Icon(Icons.shuffle_rounded,
                            color: VybeColors.textSecondary, size: 18),
                      ),
                    ),
                  ]),
                ),

              const SizedBox(height: 8),

              // ── Track list ─────────────────────────────────────────────────
              Expanded(
                child: songs.isEmpty
                    ? const Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Icon(Icons.queue_music_rounded,
                              color: VybeColors.textTertiary, size: 40),
                          SizedBox(height: 12),
                          Text('No songs yet',
                              style: TextStyle(
                                  fontFamily: 'VybeSans',
                                  fontSize: 14,
                                  color: VybeColors.textTertiary)),
                          SizedBox(height: 6),
                          Text(
                              'Long-press any song in your library to add it here',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'VybeSans',
                                  fontSize: 12,
                                  color: VybeColors.textTertiary)),
                        ]))
                    : ReorderableListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 120),
                        itemCount: songs.length,
                        onReorder: (oldIdx, newIdx) {
                          // Clamp newIdx per ReorderableListView contract
                          if (newIdx > oldIdx) newIdx--;
                          setState(() {
                            final id = _trackIds.removeAt(oldIdx);
                            _trackIds.insert(newIdx, id);
                          });
                          ref
                              .read(playlistRepoProvider)
                              .reorderTrack(widget.playlist.id, oldIdx, newIdx);
                        },
                        itemBuilder: (ctx, i) {
                          final s = songs[i];
                          final trackId = 'local_${s.id}';
                          final cur = ref.watch(currentTrackProvider);
                          final isCur = cur?.id == trackId;

                          return Dismissible(
                            // Key must NOT include index — index changes as
                            // items are removed, causing Flutter to confuse
                            // old dismissed widgets with newly-shifted ones.
                            key: ValueKey('${widget.playlist.id}_${s.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: 16),
                              color: VybeColors.error.withAlpha(30),
                              child: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: VybeColors.error,
                                  size: 20),
                            ),
                            onDismissed: (_) {
                              // ── CRITICAL: remove synchronously in setState
                              // BEFORE the async repo write.  Flutter's
                              // Dismissible requires the widget to be gone
                              // from the tree by the next frame — if you only
                              // do the async write, the list rebuilds with the
                              // item still present and throws the red screen.
                              setState(() => _trackIds.remove(trackId));
                              ref
                                  .read(playlistRepoProvider)
                                  .removeTrack(widget.playlist.id, trackId);
                            },
                            child: GestureDetector(
                              onTap: () async {
                                await ref
                                    .read(audioEngineProvider)
                                    .loadQueue(
                                      songs.map(toTrack).toList(),
                                      startIndex: i,
                                    );
                                ref
                                    .read(playerExpandedProvider.notifier)
                                    .state = true;
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 9),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  color: isCur
                                      ? VybeColors.vybeStart
                                          .withAlpha(16)
                                      : Colors.transparent,
                                ),
                                child: Row(children: [
                                  const Icon(
                                      Icons.drag_handle_rounded,
                                      color: VybeColors.textTertiary,
                                      size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s.title,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontFamily: 'VybeSans',
                                                fontSize: 14,
                                                fontWeight: isCur
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: isCur
                                                    ? VybeColors
                                                        .vybeStart
                                                    : VybeColors
                                                        .textPrimary)),
                                        Text(
                                            s.artist ?? 'Unknown',
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontFamily: 'VybeSans',
                                                fontSize: 12,
                                                color: VybeColors
                                                    .textTertiary)),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                      Icons.chevron_right_rounded,
                                      color: VybeColors.textTertiary,
                                      size: 16),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}