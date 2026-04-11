// lib/features/library/library_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/providers.dart';
import '../../core/theme/vybe_colors.dart';
import '../../data/models/track.dart';
import '../../widgets/glassmorphic_card.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

// ─── Providers ─────────────────────────────────────────────────────────────────
//
// Each provider watches [permissionGrantedProvider].
// When bootstrap flips it from false → true (after the user taps Allow),
// Riverpod invalidates these providers and they re-run automatically —
// no manual refresh or Navigator.pushReplacement required.

final permissionGrantedProvider = FutureProvider<bool>((ref) async {
  // Actually check the permission state each time this is invalidated
  final status = await Permission.audio.request();
  return status.isGranted;
});

final localTracksProvider = FutureProvider<List<SongModel>>((ref) async {
  // Re-run whenever permission state changes.
  final permissionAsync = ref.watch(permissionGrantedProvider);
  
  final granted = permissionAsync.when(
    data: (isGranted) => isGranted,
    loading: () => false,
    error: (_, __) => false,
  );
  
  if (!granted) return [];
  return OnAudioQuery().querySongs(
    sortType: SongSortType.TITLE,
    orderType: OrderType.ASC_OR_SMALLER,
    uriType: UriType.EXTERNAL,
    ignoreCase: true,
  );
});

final localAlbumsProvider = FutureProvider<List<AlbumModel>>((ref) async {
  final permissionAsync = ref.watch(permissionGrantedProvider);
  
  final granted = permissionAsync.when(
    data: (isGranted) => isGranted,
    loading: () => false,
    error: (_, __) => false,
  );
  
  if (!granted) return [];
  return OnAudioQuery().queryAlbums(
    sortType: AlbumSortType.ALBUM,
    orderType: OrderType.ASC_OR_SMALLER,
    uriType: UriType.EXTERNAL,
  );
});

final localArtistsProvider = FutureProvider<List<ArtistModel>>((ref) async {
  final permissionAsync = ref.watch(permissionGrantedProvider);
  
  final granted = permissionAsync.when(
    data: (isGranted) => isGranted,
    loading: () => false,
    error: (_, __) => false,
  );
  
  if (!granted) return [];
  return OnAudioQuery().queryArtists(
    sortType: ArtistSortType.ARTIST,
    orderType: OrderType.ASC_OR_SMALLER,
    uriType: UriType.EXTERNAL,
  );
});

final _searchQueryProvider = StateProvider<String>((ref) => '');

final _audioQueryProvider = Provider((ref) => OnAudioQuery());

final filteredSongsProvider = Provider<AsyncValue<List<SongModel>>>((ref) {
  final query = ref.watch(_searchQueryProvider).toLowerCase().trim();
  final songs = ref.watch(localTracksProvider);
  if (query.isEmpty) return songs;
  return songs.whenData((list) => list
      .where(
        (s) =>
            s.title.toLowerCase().contains(query) ||
            (s.artist ?? '').toLowerCase().contains(query) ||
            (s.album ?? '').toLowerCase().contains(query),
      )
      .toList());
});

final filteredAlbumsProvider = Provider<AsyncValue<List<AlbumModel>>>((ref) {
  final query = ref.watch(_searchQueryProvider).toLowerCase().trim();
  final albums = ref.watch(localAlbumsProvider);
  if (query.isEmpty) return albums;
  return albums.whenData(
    (list) => list.where((a) {
      final album = a.album.toLowerCase();
      final artist = (a.artist ?? '').toLowerCase();
      return album.contains(query) || artist.contains(query);
    }).toList(),
  );
});

final filteredArtistsProvider = Provider<AsyncValue<List<ArtistModel>>>((ref) {
  final query = ref.watch(_searchQueryProvider).toLowerCase().trim();
  final artists = ref.watch(localArtistsProvider);
  if (query.isEmpty) return artists;
  return artists.whenData(
    (list) =>
        list.where((a) => a.artist.toLowerCase().contains(query)).toList(),
  );
});

// Perf guard: animate only the first visible items.
const int _kAnimatedItemsLimit = 40;

// ─── Screen ────────────────────────────────────────────────────────────────────

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  bool _searchFocused = false;
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(_searchQueryProvider.notifier).state = v;
    });
  }

  void _dismissKeyboard() {
    _searchFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);

    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });

    _tab.addListener(() {
      if (_tab.indexIsChanging) _dismissKeyboard();
    });

    // Check permission state when screen comes into focus
    // (catches permission grants from Settings)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(permissionGrantedProvider);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tab.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VybeColors.background,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row: tiny wordmark + waveform ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Row(children: [
              // Small, subtle wordmark — content is the star, not the name
              ShaderMask(
                shaderCallback: (b) => VybeColors.vybeGradient.createShader(b),
                child: const Text(
                  'VYBE',
                  style: TextStyle(
                    fontFamily: 'VybeSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const Spacer(),
              Consumer(builder: (_, ref, __) {
                final playing = ref.watch(isPlayingProvider);
                return WaveformBars(
                    isPlaying: playing, height: 16, barCount: 4, barWidth: 2.5);
              }),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Inline search bar ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _searchFocused
                    ? VybeColors.surfaceElevated
                    : VybeColors.surfaceGlass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _searchFocused
                      ? VybeColors.vybeStart.withAlpha(80)
                      : VybeColors.border,
                  width: _searchFocused ? 1.0 : 0.5,
                ),
              ),
              child: Row(children: [
                const SizedBox(width: 14),
                Icon(Icons.search_rounded,
                    size: 18,
                    color: _searchFocused
                        ? VybeColors.vybeStart
                        : VybeColors.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    onTapOutside: (_) => _dismissKeyboard(),
                    onSubmitted: (_) => _dismissKeyboard(),
                    style: const TextStyle(
                        fontFamily: 'VybeSans',
                        fontSize: 14,
                        color: VybeColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Songs, artists, albums…',
                      hintStyle: TextStyle(
                          fontFamily: 'VybeSans',
                          fontSize: 14,
                          color: VybeColors.textTertiary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          ref.read(_searchQueryProvider.notifier).state = '';
                          _dismissKeyboard();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: VybeColors.textTertiary,
                          ),
                        ),
                      );
                    },
                  ),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // ── Tab bar ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: VybeColors.surfaceGlass,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tab,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: VybeColors.vybeGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelStyle: const TextStyle(
                    fontFamily: 'VybeSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontFamily: 'VybeSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400),
                labelColor: Colors.white,
                unselectedLabelColor: VybeColors.textTertiary,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Songs'),
                  Tab(text: 'Albums'),
                  Tab(text: 'Artists')
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ── Content ─────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _SongsTab(),
                _AlbumsTab(),
                _ArtistsTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Songs Tab ─────────────────────────────────────────────────────────────────

class _SongsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(filteredSongsProvider);
    return songs.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(VybeColors.vybeStart))),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (list) {
        if (list.isEmpty) return const _EmptyState();
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
          itemCount: list.length,
          cacheExtent: 700,
          itemBuilder: (ctx, i) => _SongTile(
            key: ValueKey(list[i].id),
            song: list[i],
            allSongs: list,
            index: i,
          ),
        );
      },
    );
  }
}

class _SongTile extends ConsumerStatefulWidget {
  final SongModel song;
  final List<SongModel> allSongs;
  final int index;
  const _SongTile(
      {super.key,
      required this.song,
      required this.allSongs,
      required this.index});
  @override
  ConsumerState<_SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<_SongTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _slide = Tween(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));

    if (widget.index >= _kAnimatedItemsLimit) {
      _ac.value = 1.0; // skip animation for most rows
      return;
    }

    Future.delayed(Duration(milliseconds: widget.index.clamp(0, 25) * 20), () {
      if (mounted) _ac.forward();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Track _toTrack(SongModel s) => Track(
        id: 'local_${s.id}',
        title: s.title,
        artist: s.artist ?? 'Unknown',
        album: s.album ?? '',
        localPath: s.uri,
        durationMs: s.duration ?? 0,
        sourceType: TrackSource.local.name,
      );

  void _showContextMenu(BuildContext context) {
    final playlists = ref.read(playlistRepoProvider).getAll();
    showModalBottomSheet(
      context: context,
      backgroundColor: VybeColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _TrackContextMenu(
        track: _toTrack(widget.song),
        playlists: playlists,
        // Do action only here; don't pop using the outer context.
        onAddNext: () {
          ref.read(audioEngineProvider).addNext(_toTrack(widget.song));
        },
        onAddToQueue: () {
          ref.read(audioEngineProvider).addToQueue(_toTrack(widget.song));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final isCurrent = currentTrack?.id == 'local_${widget.song.id}';

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: () async {
            FocusManager.instance.primaryFocus
                ?.unfocus(); // hide keyboard first
            final engine = ref.read(audioEngineProvider);
            final tracks = widget.allSongs.map(_toTrack).toList();
            await engine.loadQueue(tracks, startIndex: widget.index);

            // Keep collapsed mini player on song tap.
            ref.read(playerExpandedProvider.notifier).state = false;
          },
          onLongPress: () => _showContextMenu(context),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isCurrent
                  ? VybeColors.vybeStart.withAlpha(16)
                  : Colors.transparent,
            ),
            child: Row(children: [
              // Artwork
              _Artwork(
                  songId: widget.song.id, isPlaying: isCurrent && isPlaying),
              const SizedBox(width: 12),
              // Text
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'VybeSans',
                        fontSize: 14,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w500,
                        color: isCurrent
                            ? VybeColors.vybeStart
                            : VybeColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    widget.song.artist ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'VybeSans',
                        fontSize: 12,
                        color: VybeColors.textTertiary),
                  ),
                ],
              )),
              // Duration
              Text(_fmt(widget.song.duration),
                  style: const TextStyle(
                      fontFamily: 'VybeSans',
                      fontSize: 12,
                      color: VybeColors.textTertiary)),
              const SizedBox(width: 4),
            ]),
          ),
        ),
      ),
    );
  }

  String _fmt(int? ms) {
    if (ms == null) return '--:--';
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

// ─── Track context menu ────────────────────────────────────────────────────────

class _TrackContextMenu extends ConsumerWidget {
  final Track track;
  final List<dynamic> playlists;
  final VoidCallback onAddNext;
  final VoidCallback onAddToQueue;

  const _TrackContextMenu({
    required this.track,
    required this.playlists,
    required this.onAddNext,
    required this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: VybeColors.textTertiary,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text(track.title,
            style: const TextStyle(
                fontFamily: 'VybeSans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: VybeColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(track.artist,
            style: const TextStyle(
                fontFamily: 'VybeSans',
                fontSize: 12,
                color: VybeColors.textTertiary)),
        const SizedBox(height: 20),
        _ContextOption(
            icon: Icons.skip_next_rounded,
            label: 'Play Next',
            onTap: onAddNext),
        _ContextOption(
            icon: Icons.queue_music_rounded,
            label: 'Add to Queue',
            onTap: onAddToQueue),
        if (playlists.isNotEmpty) ...([
          const SizedBox(height: 8),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('ADD TO PLAYLIST',
                  style: TextStyle(
                      fontFamily: 'VybeSans',
                      fontSize: 10,
                      color: VybeColors.textTertiary,
                      letterSpacing: 2))),
          const SizedBox(height: 6),
          ...playlists.map((pl) => _ContextOption(
                icon: Icons.playlist_add_rounded,
                label: pl.name as String,
                onTap: () {
                  ref
                      .read(playlistRepoProvider)
                      .addTrack(pl.id as String, track.id);
                  Navigator.pop(context);
                },
              ))
        ]),
      ]),
    );
  }
}

class _ContextOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ContextOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(icon, size: 20, color: VybeColors.textSecondary),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'VybeSans',
                    fontSize: 14,
                    color: VybeColors.textPrimary)),
          ]),
        ),
      );
}

// ─── Albums Tab ────────────────────────────────────────────────────────────────

class _AlbumsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(filteredAlbumsProvider);
    return albums.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(VybeColors.vybeStart))),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (list) {
        if (list.isEmpty) return const _EmptyState();
        return GridView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: list.length,
          itemBuilder: (ctx, i) => _AlbumCard(album: list[i], index: i),
        );
      },
    );
  }
}

class _AlbumCard extends ConsumerStatefulWidget {
  final AlbumModel album;
  final int index;
  const _AlbumCard({required this.album, required this.index});
  @override
  ConsumerState<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends ConsumerState<_AlbumCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;

  Track _toTrack(SongModel s) => Track(
        id: 'local_${s.id}',
        title: s.title,
        artist: s.artist ?? 'Unknown',
        album: s.album ?? '',
        localPath: s.uri,
        durationMs: s.duration ?? 0,
        sourceType: TrackSource.local.name,
      );

  Future<void> _playAlbum() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final songs = await ref.read(_audioQueryProvider).queryAudiosFrom(
          AudiosFromType.ALBUM_ID,
          widget.album.id,
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          ignoreCase: true,
        );

    if (songs.isEmpty) return;

    final engine = ref.read(audioEngineProvider);
    await engine.loadQueue(songs.map(_toTrack).toList(), startIndex: 0);

    // Always disable shuffle when playing album
    if (engine.currentState.shuffleEnabled) {
      await engine.toggleShuffle();
    }

    // Keep mini player collapsed
    ref.read(playerExpandedProvider.notifier).state = false;
  }

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));

    if (widget.index >= _kAnimatedItemsLimit) {
      _ac.value = 1.0; // skip animation for most cards
      return;
    }

    Future.delayed(Duration(milliseconds: widget.index.clamp(0, 20) * 40), () {
      if (mounted) _ac.forward();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AlbumDetailScreen(album: widget.album),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: VybeColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VybeColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    child: RepaintBoundary(
                      child: QueryArtworkWidget(
                        id: widget.album.id,
                        type: ArtworkType.ALBUM,
                        artworkFit: BoxFit.cover,
                        artworkBorder: BorderRadius.zero,
                        artworkWidth: double.infinity,
                        nullArtworkWidget: Container(
                          decoration: const BoxDecoration(
                              gradient: VybeColors.vybeGradientFull),
                          child: const Center(
                              child: Icon(Icons.album_rounded,
                                  color: Colors.white38, size: 40)),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.album.album,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'VybeSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: VybeColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.album.artist ?? ''} · ${widget.album.numOfSongs} songs',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'VybeSans',
                                fontSize: 11,
                                color: VybeColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          // Stop the outer card tap from firing
                          // play album in mini-player
                          await _playAlbum();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: VybeColors.surfaceGlass,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: VybeColors.border, width: 0.5),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                            color: VybeColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Artists Tab ───────────────────────────────────────────────────────────────

class _ArtistsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(filteredArtistsProvider);
    return artists.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(VybeColors.vybeStart))),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (list) {
        if (list.isEmpty) return const _EmptyState();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
          itemCount: list.length,
          cacheExtent: 700,
          itemBuilder: (ctx, i) => _ArtistTile(artist: list[i], index: i),
        );
      },
    );
  }
}

class _ArtistTile extends StatefulWidget {
  final ArtistModel artist;
  final int index;
  const _ArtistTile({required this.artist, required this.index});
  @override
  State<_ArtistTile> createState() => _ArtistTileState();
}

class _ArtistTileState extends State<_ArtistTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _slide = Tween(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));

    if (widget.index >= _kAnimatedItemsLimit) {
      _ac.value = 1.0; // skip animation for most rows
      return;
    }

    Future.delayed(Duration(milliseconds: widget.index.clamp(0, 25) * 20), () {
      if (mounted) _ac.forward();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artist: widget.artist),
          )),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      VybeColors.vybeStart.withAlpha(80),
                      VybeColors.vybeDeep.withAlpha(80),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    (widget.artist.artist.isNotEmpty
                            ? widget.artist.artist[0]
                            : '?')
                        .toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'VybeDisplay',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.artist.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'VybeSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: VybeColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.artist.numberOfAlbums ?? 0} albums · ${widget.artist.numberOfTracks ?? 0} songs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'VybeSans',
                          fontSize: 12,
                          color: VybeColors.textTertiary,
                        ),
                      ),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: VybeColors.textTertiary, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Artwork widget ─────────────────────────────────────────────────────────────

class _Artwork extends StatelessWidget {
  final int songId;
  final bool isPlaying;
  const _Artwork({required this.songId, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
          color: VybeColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: RepaintBoundary(
          child: QueryArtworkWidget(
            id: songId,
            type: ArtworkType.AUDIO,
            artworkBorder: BorderRadius.zero,
            nullArtworkWidget: Container(
                color: VybeColors.surfaceElevated,
                child: const Icon(Icons.music_note_rounded,
                    color: VybeColors.textTertiary, size: 22)),
          ),
        ),
      ),
    );
  }
}

// ─── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends ConsumerWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
              shaderCallback: (b) => VybeColors.vybeGradient.createShader(b),
              child: const Icon(Icons.library_music_rounded,
                  color: Colors.white, size: 56)),
          const SizedBox(height: 16),
          const Text('No music found',
              style: TextStyle(
                  fontFamily: 'VybeDisplay',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: VybeColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Add music files to your device',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'VybeSans',
                  fontSize: 13,
                  color: VybeColors.textTertiary)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              ref.invalidate(localTracksProvider);
              ref.invalidate(localAlbumsProvider);
              ref.invalidate(localArtistsProvider);
              ref.invalidate(permissionGrantedProvider);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: VybeColors.vybeStart,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'VybeSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: VybeColors.error, size: 40),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: VybeColors.textTertiary, fontSize: 13)),
          ]),
        ),
      );
}
