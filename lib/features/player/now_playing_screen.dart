// lib/features/player/now_playing_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/providers.dart';
import '../../core/theme/vybe_colors.dart';
import '../../core/dynamic_palette_notifier.dart';
import '../../data/models/track.dart';
import '../../audio/vybe_audio_engine.dart' show DspMode;
import '../equalizer/equalizer_screen.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});
  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late AnimationController _artCtrl;
  late Animation<double> _artScale;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380))
      ..forward();
    _artCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _artScale = Tween(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _artCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _artCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final position = ref.watch(playerPositionProvider);
    final duration = ref.watch(playerDurationProvider);
    final stateVal = ref.watch(playerStateProvider).value;
    final engine = ref.read(audioEngineProvider);
    final palette = ref.watch(dynamicPaletteProvider).valueOrNull ??
        DynamicPalette.fallback;

    ref.listen(currentTrackProvider, (prev, next) {
      if (prev?.id != next?.id) {
        _artCtrl.reset();
        _artCtrl.forward();
      }
    });

    if (track == null) return const SizedBox.shrink();

    final loopMode = stateVal?.loopMode ?? LoopMode.off;
    final shuffleEnabled = stateVal?.shuffleEnabled ?? false;
    final tier = stateVal?.activeTier ?? PlaybackTier.standard;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(fit: StackFit.expand, children: [
        _Background(track: track, palette: palette),
        SafeArea(
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: _slideCtrl, curve: Curves.easeOutCubic)),
            child: Column(children: [
              _Header(
                  onClose: () =>
                      ref.read(playerExpandedProvider.notifier).state = false),
              if (!_showLyrics)
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ScaleTransition(
                      scale: _artScale,
                      child: _AlbumArt(
                          track: track,
                          isPlaying: isPlaying,
                          glowColor: palette.vibrant),
                    ),
                  ),
                ),
              Expanded(
                flex: _showLyrics ? 10 : 4,
                child: _showLyrics
                    ? _LyricsPanel(track: track, position: position)
                    : _TrackInfo(track: track, tier: tier),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _SeekBar(
                    position: position,
                    duration: duration,
                    onSeek: engine.seek,
                    accentColor: palette.vibrant),
              ),
              const SizedBox(height: 8),
              _Controls(
                isPlaying: isPlaying,
                loopMode: loopMode,
                shuffleEnabled: shuffleEnabled,
                onPlayPause: engine.togglePlayPause,
                onNext: engine.skipNext,
                onPrevious: engine.skipPrevious,
                onToggleShuffle: engine.toggleShuffle,
                onCycleLoop: engine.cycleLoopMode,
              ),
              const SizedBox(height: 16),
              _BottomChips(
                showLyrics: _showLyrics,
                onToggleLyrics: () =>
                    setState(() => _showLyrics = !_showLyrics),
                onOpenEq: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const EqBottomSheet(),
                ),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Background ─────────────────────────────────────────────────────────────

class _Background extends StatelessWidget {
  final Track track;
  final DynamicPalette palette;
  const _Background({required this.track, required this.palette});

  @override
  Widget build(BuildContext context) {
    final songId = track.isLocal
        ? int.tryParse(track.id.replaceFirst('local_', ''))
        : null;

    return Stack(fit: StackFit.expand, children: [
      Container(
          decoration: const BoxDecoration(gradient: VybeColors.playerGradient)),

      // Blurred artwork background
      if (songId != null)
        Positioned.fill(
          child: QueryArtworkWidget(
            id: songId,
            type: ArtworkType.AUDIO,
            artworkBorder: BorderRadius.zero,
            artworkFit: BoxFit.cover,
            artworkWidth: double.infinity,
            artworkHeight: double.infinity,
            nullArtworkWidget: const SizedBox.shrink(),
          ),
        ),

      BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(color: VybeColors.background.withAlpha(170))),

      // Dynamic tint — animated on track change
      AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        color: palette.tint.withAlpha(110),
      ),

      // Vignette
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xCC080810), Colors.transparent, Color(0xCC080810)],
            stops: [0.0, 0.4, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    ]);
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(children: [
          GestureDetector(
            onTap: onClose,
            child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: VybeColors.surfaceGlass,
                    shape: BoxShape.circle,
                    border: Border.all(color: VybeColors.border)),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: VybeColors.textSecondary, size: 26)),
          ),
          const Expanded(
              child: Center(
            child: Text('NOW PLAYING',
                style: TextStyle(
                    fontFamily: 'VybeSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: VybeColors.textTertiary,
                    letterSpacing: 2)),
          )),
          const SizedBox(width: 40),
        ]),
      );
}

// ─── Album Art ──────────────────────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final Color glowColor;
  const _AlbumArt(
      {required this.track, required this.isPlaying, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final songId = track.isLocal
        ? int.tryParse(track.id.replaceFirst('local_', ''))
        : null;

    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: glowColor.withAlpha(110),
                blurRadius: 60,
                spreadRadius: 10,
                offset: const Offset(0, 20)),
            BoxShadow(
                color: Colors.black.withAlpha(128),
                blurRadius: 40,
                offset: const Offset(0, 10)),
          ],
        ),
        transform: Matrix4.identity()
          ..scaleByDouble(
            isPlaying ? 1.0 : 0.94, // x
            isPlaying ? 1.0 : 0.94, // y
            1.0, // z
            1.0, // w
          ),
        transformAlignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: songId != null
              ? QueryArtworkWidget(
                  id: songId,
                  type: ArtworkType.AUDIO,
                  artworkBorder: BorderRadius.zero,
                  artworkFit: BoxFit.cover,
                  artworkWidth: double.infinity,
                  artworkHeight: double.infinity,
                  nullArtworkWidget: _DefaultArt())
              : _DefaultArt(),
        ),
      ),
    );
  }
}

class _DefaultArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(gradient: VybeColors.vybeGradientFull),
      child: const Center(
          child:
              Icon(Icons.music_note_rounded, color: Colors.white38, size: 80)));
}

// ─── Track Info ─────────────────────────────────────────────────────────────

class _TrackInfo extends StatelessWidget {
  final Track track;
  final PlaybackTier tier;
  const _TrackInfo({required this.track, required this.tier});

  Color get _tierColor => switch (tier) {
        PlaybackTier.bitPerfect => VybeColors.tierBitPerfect,
        PlaybackTier.hiRes => VybeColors.tierHiRes,
        _ => VybeColors.tierStandard,
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'VybeDisplay',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: VybeColors.textPrimary,
                      letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'VybeSans',
                      fontSize: 16,
                      color: VybeColors.textSecondary)),
              if (track.qualityBadge.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _tierColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _tierColor.withAlpha(77), width: 0.5)),
                  child: Text(track.qualityBadge,
                      style: TextStyle(
                          fontFamily: 'VybeSans',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _tierColor,
                          letterSpacing: 0.5)),
                ),
              ],
            ]),
      );
}

// ─── Seek Bar ───────────────────────────────────────────────────────────────

class _SeekBar extends StatefulWidget {
  final Duration position;
  final Duration? duration;
  final Future<void> Function(Duration) onSeek;
  final Color accentColor;
  const _SeekBar(
      {required this.position,
      required this.duration,
      required this.onSeek,
      required this.accentColor});
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _dragging = false;
  double _dragVal = 0;

  String _fmt(Duration? d) {
    if (d == null) return '--:--';
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (_dragging) return _dragVal;
    final ms = widget.duration?.inMilliseconds ?? 0;
    if (ms == 0) return 0;
    return (widget.position.inMilliseconds / ms).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: widget.accentColor,
          inactiveTrackColor: VybeColors.surfaceGlass,
          thumbColor: Colors.white,
          overlayColor: widget.accentColor.withAlpha(51),
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        ),
        child: Slider(
          value: _progress,
          onChangeStart: (v) => setState(() {
            _dragging = true;
            _dragVal = v;
          }),
          onChanged: (v) => setState(() => _dragVal = v),
          onChangeEnd: (v) {
            final dur = widget.duration;
            if (dur != null) {
              widget.onSeek(
                  Duration(milliseconds: (v * dur.inMilliseconds).round()));
            }
            setState(() => _dragging = false);
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
              _fmt(_dragging && widget.duration != null
                  ? Duration(
                      milliseconds:
                          (_dragVal * widget.duration!.inMilliseconds).round())
                  : widget.position),
              style: const TextStyle(
                  fontFamily: 'VybeSans',
                  fontSize: 12,
                  color: VybeColors.textTertiary)),
          Text(_fmt(widget.duration),
              style: const TextStyle(
                  fontFamily: 'VybeSans',
                  fontSize: 12,
                  color: VybeColors.textTertiary)),
        ]),
      ),
    ]);
  }
}

// ─── Controls ───────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final bool isPlaying;
  final LoopMode loopMode;
  final bool shuffleEnabled;
  final Future<void> Function() onPlayPause,
      onNext,
      onPrevious,
      onToggleShuffle,
      onCycleLoop;
  const _Controls(
      {required this.isPlaying,
      required this.loopMode,
      required this.shuffleEnabled,
      required this.onPlayPause,
      required this.onNext,
      required this.onPrevious,
      required this.onToggleShuffle,
      required this.onCycleLoop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _Btn(
            icon: Icons.shuffle_rounded,
            active: shuffleEnabled,
            onTap: onToggleShuffle),
        _Btn(
            icon: Icons.skip_previous_rounded,
            size: 36,
            color: VybeColors.textPrimary,
            onTap: onPrevious),
        GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: VybeColors.vybeGradient,
                boxShadow: [
                  BoxShadow(
                      color: VybeColors.vybeStart.withAlpha(102),
                      blurRadius: 30,
                      spreadRadius: 2)
                ]),
            child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey(isPlaying),
                    color: Colors.white,
                    size: 36)),
          ),
        ),
        _Btn(
            icon: Icons.skip_next_rounded,
            size: 36,
            color: VybeColors.textPrimary,
            onTap: onNext),
        _Btn(
            icon: loopMode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            active: loopMode != LoopMode.off,
            onTap: onCycleLoop),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool active;
  final Color? color;
  final Future<void> Function() onTap;
  const _Btn(
      {required this.icon,
      this.size = 26,
      this.active = false,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon,
                size: size,
                color: active
                    ? VybeColors.vybeStart
                    : (color ?? VybeColors.textSecondary))),
      );
}

// ─── Bottom chips ────────────────────────────────────────────────────────────

class _BottomChips extends ConsumerWidget {
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final VoidCallback onOpenEq;
  const _BottomChips({
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onOpenEq,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dspMode = ref.watch(dspModeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Lyrics chip — left. EQ chip — right, active when Enhanced mode is on.
        _Chip(
            icon: Icons.lyrics_rounded,
            label: 'Lyrics',
            active: showLyrics,
            onTap: onToggleLyrics),
        const SizedBox(width: 20),
        _Chip(
            icon: Icons.equalizer_rounded,
            label: 'EQ',
            active: dspMode == DspMode.enhanced,
            onTap: onOpenEq),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip(
      {required this.icon,
      required this.label,
      this.active = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: active
                    ? VybeColors.vybeStart.withAlpha(38)
                    : VybeColors.surfaceGlass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: active
                        ? VybeColors.vybeStart.withAlpha(102)
                        : VybeColors.border,
                    width: 0.5)),
            child: Icon(icon,
                size: 22,
                color:
                    active ? VybeColors.vybeStart : VybeColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: 'VybeSans',
                  fontSize: 11,
                  color:
                      active ? VybeColors.vybeStart : VybeColors.textTertiary,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

// ─── Lyrics Panel ────────────────────────────────────────────────────────────

class _LyricsPanel extends ConsumerStatefulWidget {
  final Track track;
  final Duration position;
  const _LyricsPanel({required this.track, required this.position});
  @override
  ConsumerState<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<_LyricsPanel> {
  final ScrollController _scroll = ScrollController();
  int _lastIndex = -1;
  static const _lineH = 52.0;
  static const _topPad = 16.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToLine(int i) {
    if (!_scroll.hasClients) return;
    final target = (_topPad + i * _lineH) -
        (_scroll.position.viewportDimension / 2) +
        (_lineH / 2);
    _scroll.animateTo(target.clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider(widget.track));

    return lyricsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(VybeColors.vybeStart),
              strokeWidth: 2)),
      error: (_, __) => const Center(
          child: Text('Lyrics unavailable',
              style: TextStyle(color: VybeColors.textTertiary))),
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lyrics_outlined,
                color: VybeColors.textTertiary, size: 40),
            SizedBox(height: 12),
            Text('No lyrics found',
                style: TextStyle(
                    color: VybeColors.textTertiary,
                    fontFamily: 'VybeSans',
                    fontSize: 14)),
          ]));
        }

        int currentIndex = 0;
        if (lyrics.isSynced) {
          // Binary search for current line
          int lo = 0, hi = lyrics.lines.length - 1;
          while (lo <= hi) {
            final mid = (lo + hi) >> 1;
            final ts = lyrics.lines[mid].timestamp ?? Duration.zero;
            if (ts <= widget.position) {
              currentIndex = mid;
              lo = mid + 1;
            } else {
              hi = mid - 1;
            }
          }

          if (widget.position.inMilliseconds < 500 && _lastIndex > 3) {
            _lastIndex = -1;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) _scroll.jumpTo(0);
            });
          } else if (currentIndex != _lastIndex) {
            _lastIndex = currentIndex;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToLine(currentIndex));
          }
        }

        return Stack(children: [
          ListView.builder(
            controller: _scroll,
            itemExtent: _lineH,
            padding: const EdgeInsets.fromLTRB(28, _topPad, 28, 80),
            itemCount: lyrics.lines.length,
            itemBuilder: (_, i) {
              final isCur = lyrics.isSynced && i == currentIndex;
              return Text(lyrics.lines[i].text,
                  style: TextStyle(
                      color: isCur
                          ? VybeColors.vybeStart
                          : VybeColors.textSecondary,
                      fontSize: 16));
            },
          ),
          if (lyrics.isAiGenerated)
            Positioned(
                top: 8,
                right: 28,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: VybeColors.vybeDeep.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: VybeColors.vybeDeep.withAlpha(77))),
                  child: const Text('AI Generated',
                      style: TextStyle(
                          fontFamily: 'VybeSans',
                          fontSize: 10,
                          color: VybeColors.vybeDeep,
                          fontWeight: FontWeight.w600)),
                )),
        ]);
      },
    );
  }
}