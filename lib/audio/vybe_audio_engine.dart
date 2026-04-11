// lib/audio/vybe_audio_engine.dart
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import '../data/models/track.dart';
import '../core/persistence.dart';
import '../core/app_globals.dart';
import 'platform_channels/bit_perfect_channel.dart';
import 'package:flutter/widgets.dart'; // Add this import

/// Two real, audibly different engine modes.
///
/// [transparent] — bypass ALL processing. The decoded PCM reaches your
///   headphones without modification. Every detail the mastering engineer
///   intended, nothing added. Best for lossless (FLAC/WAV/ALAC).
///
/// [enhanced] — warm, lively processing chain. Applied EQ curve adds
///   +4dB sub-bass, +3dB bass warmth, +2dB presence, +3dB air. Loudness
///   enhancer at +3dB. Audibly fuller and louder. Best for MP3/AAC.
enum DspMode { transparent, enhanced }

class VybePlayerState {
  final Track? currentTrack;
  final PlayerState playerState;
  final Duration position;
  final Duration? duration;
  final double volume;
  final bool shuffleEnabled;
  final LoopMode loopMode;
  final PlaybackTier activeTier;
  final int currentIndex;
  final List<Track> queue;

  const VybePlayerState({
    this.currentTrack,
    required this.playerState,
    this.position = Duration.zero,
    this.duration,
    this.volume = 1.0,
    this.shuffleEnabled = false,
    this.loopMode = LoopMode.off,
    this.activeTier = PlaybackTier.standard,
    this.currentIndex = 0,
    this.queue = const [],
  });

  bool get isPlaying => playerState.playing;
  bool get isLoading =>
      playerState.processingState == ProcessingState.loading ||
      playerState.processingState == ProcessingState.buffering;
  double get progress => (duration?.inMilliseconds ?? 0) > 0
      ? (position.inMilliseconds / duration!.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  VybePlayerState copyWith({
    Track? currentTrack,
    PlayerState? playerState,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? shuffleEnabled,
    LoopMode? loopMode,
    PlaybackTier? activeTier,
    int? currentIndex,
    List<Track>? queue,
  }) =>
      VybePlayerState(
        currentTrack: currentTrack ?? this.currentTrack,
        playerState: playerState ?? this.playerState,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        volume: volume ?? this.volume,
        shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
        loopMode: loopMode ?? this.loopMode,
        activeTier: activeTier ?? this.activeTier,
        currentIndex: currentIndex ?? this.currentIndex,
        queue: queue ?? this.queue,
      );
}

// EQ gains (dB) for Enhanced mode — 10 standard bands.
// Conservative warmth boost: +1.5dB lows, +0.5dB mids, +1dB air. Safe for all speakers.
const enhancedEqDefaultGains = <double>[
  1.5, // 60 Hz
  1.0, // 150 Hz
  0.5, // 400 Hz
  0.0, // 1 kHz
  0.0, // 2.5 kHz
  0.0, // 4 kHz
  0.5, // 6 kHz
  0.8, // 10 kHz
  1.0, // 12.5 kHz
  1.2 // 16 kHz
];

class VybeAudioEngine with WidgetsBindingObserver {
  late AudioPlayer _player;
  late ConcatenatingAudioSource _playlist;
  AndroidEqualizer? _equalizer;
  AndroidLoudnessEnhancer? _loudnessEnhancer;

  // Modest loudness boost for enhanced mode (millibels). +900 = +0.9 dB.
  static const double _enhancedLoudnessGain = 900.0;

  final List<Track> _queue = [];
  int _currentIndex = 0;
  PlaybackTier _activeTier = PlaybackTier.standard;
  DspMode _dspMode = DspMode.transparent;
  bool _dspTransitioning = false;
  // Tracks current EQ band gains — updated by applyEqGains/setEqualizerBandGain
  List<double> _currentEqGains = List<double>.from(enhancedEqDefaultGains);
  List<double> get currentEqGains => List<double>.unmodifiable(_currentEqGains);

  double? _lastAppliedLoudnessGain;
  Timer? _loudnessDebounceTimer;

  late VybePersistence _persistence;

  final _stateController = BehaviorSubject<VybePlayerState>();
  Stream<VybePlayerState> get stateStream => _stateController.stream;
  VybePlayerState get currentState =>
      _stateController.valueOrNull ??
      VybePlayerState(playerState: PlayerState(false, ProcessingState.idle));

  bool _initialized = false;
  DspMode get currentDspMode => _dspMode;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register as a lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    _persistence = await VybePersistence.load();
    _dspMode = _persistence.dspMode;

    // Detect device tier (non-blocking — fallback to standard on any error)
    try {
      final caps = await HiResAudioChannel.getDeviceCapabilities();
      _activeTier = caps.recommendedTier >= 1
          ? PlaybackTier.hiRes
          : PlaybackTier.standard;
    } catch (_) {
      _activeTier = PlaybackTier.standard;
    }

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Pause on audio interruption (calls, notifications), resume when done.
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        _player.pause();
      }
      // Remove the automatic resume logic
    });

    await _initPlayer();
    _bindStreams();
    await _restoreState();
  }

  Future<void> _initPlayer() async {
    _equalizer = AndroidEqualizer();
    _loudnessEnhancer = AndroidLoudnessEnhancer();

    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [_equalizer!, _loudnessEnhancer!],
      ),
      handleInterruptions: true,
    );

    // Log playback errors — never let them propagate.
    _player.playbackEventStream.listen(
      (_) {},
      onError: (e, st) {
        debugPrint('[VYBE Engine] Playback error (handled): $e');
      },
    );

    _playlist = ConcatenatingAudioSource(children: []);
    await _player.setAudioSource(_playlist, preload: false).catchError((e) {
      debugPrint('[VYBE Engine] setAudioSource error: $e');
      return null;
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
      }
    });
  }

  void _bindStreams() {
    Rx.combineLatest5(
      _player.playerStateStream,
      _player.positionStream,
      _player.durationStream,
      _player.currentIndexStream,
      _player.shuffleModeEnabledStream,
      (ps, pos, dur, idx, shuffle) => VybePlayerState(
        currentTrack: (idx != null && idx < _queue.length) ? _queue[idx] : null,
        playerState: ps,
        position: pos,
        duration: dur,
        volume: _player.volume,
        shuffleEnabled: shuffle,
        loopMode: _player.loopMode,
        activeTier: _activeTier,
        currentIndex: idx ?? 0,
        queue: List.unmodifiable(_queue),
      ),
    ).listen(_stateController.add);
  }

  Future<void> _restoreState() async {
    await _player.setLoopMode(_persistence.loopMode);
    await _player.setShuffleModeEnabled(_persistence.shuffle);
    await _applyDspNow(_dspMode);
    // Ensure loudness enhancer state matches restored volume / mode
    await _syncLoudnessToVolume(_player.volume, immediate: false);
  }

  // ─── DSP ──────────────────────────────────────────────────────────────────

  /// Apply the chosen DSP mode.
  ///
  /// AudioEffectsChannel calls are wrapped individually — a MissingPlugin
  /// exception (e.g. during dev hot-restart) is non-fatal and logged only.
  Future<void> _applyDspNow(DspMode mode) async {
    if (_dspTransitioning) {
      debugPrint(
          '[VYBE] DSP transition already in progress; skipping duplicate apply.');
      return;
    }

    _dspTransitioning = true;
    try {
      switch (mode) {
        case DspMode.transparent:
          // Disable enhanced audio — reset everything to neutral
          try {
            await _loudnessEnhancer?.setTargetGain(0.0);
          } catch (e) {
            debugPrint('[VYBE] setTargetGain(0) skipped: $e');
          }
          try {
            await _loudnessEnhancer?.setEnabled(false);
          } catch (e) {
            debugPrint('[VYBE] Loudness disable skipped: $e');
          }
          try {
            await _equalizer?.setEnabled(false);
          } catch (e) {
            debugPrint('[VYBE] EQ disable skipped: $e');
          }
          // Reset EQ gains in memory to flat
          _currentEqGains = List<double>.filled(_currentEqGains.length, 0.0);
          break;

        case DspMode.enhanced:
          // Enable EQ first, then apply gains, then wait for loudness
          try {
            await _equalizer?.setEnabled(true);
          } catch (e) {
            debugPrint('[VYBE] EQ enable skipped: $e');
          }

          // Brief settle before applying EQ gains
          await Future.delayed(const Duration(milliseconds: 50));
          await _applyEnhancedEq();

          // Brief settle before checking volume and enabling loudness
          await Future.delayed(const Duration(milliseconds: 50));

          // DON'T enable loudness here — let _syncLoudnessToVolume handle it
          // based on current device volume
          break;
      }
    } catch (e) {
      debugPrint('[VYBE] _applyDspNow error (non-fatal): $e');
    } finally {
      _dspTransitioning = false;
    }

    // THIS MUST RUN AFTER DSP mode is set but WITH immediate flag
    await _syncLoudnessToVolume(_player.volume, immediate: true);
    debugPrint('[VYBE] DSP mode: ${mode.name}');
  }

  // Sync loudness enhancer enabled state to current app volume and DSP mode.
  // Policy: only enable the enhancer when in enhanced mode and volume is below
  // a safe threshold to avoid pushing the signal into clipping on high volume.
  Future<void> _syncLoudnessToVolume(double? volume,
      {bool immediate = false}) async {
    // Cancel any pending loudness write
    _loudnessDebounceTimer?.cancel();

    await _doSyncLoudness(volume ?? _player.volume, immediate);
  }

  // Helper function to actually apply loudness settings
  Future<void> _doSyncLoudness(double v, bool immediate) async {
    // If immediate (mode switch), execute now. Otherwise debounce volume slider.
    if (immediate) {
      await _doApplyLoudness(v);
    } else {
      _loudnessDebounceTimer =
          Timer(const Duration(milliseconds: 150), () => _doApplyLoudness(v));
    }
  }

  Future<void> _doApplyLoudness(double v) async {
    try {
      final shouldEnable = (_dspMode == DspMode.enhanced) && v < 0.95;

      // Determine the target gain
      final targetGain = shouldEnable ? _enhancedLoudnessGain : 0.0;

      // GATE: Only write if gain has actually changed
      if (_lastAppliedLoudnessGain == targetGain) {
        return; // No change needed
      }
      _lastAppliedLoudnessGain = targetGain;

      if (shouldEnable) {
        try {
          await _loudnessEnhancer?.setEnabled(true);
        } catch (e) {
          debugPrint('[VYBE] Loudness enable skipped: $e');
        }
        try {
          await _loudnessEnhancer?.setTargetGain(_enhancedLoudnessGain);
        } catch (e) {
          debugPrint('[VYBE] setTargetGain skipped: $e');
        }
      } else {
        try {
          await _loudnessEnhancer?.setTargetGain(0.0);
        } catch (e) {
          debugPrint('[VYBE] setTargetGain(0) skipped: $e');
        }
        try {
          await _loudnessEnhancer?.setEnabled(false);
        } catch (e) {
          debugPrint('[VYBE] Loudness disable skipped: $e');
        }
      }
    } catch (e) {
      debugPrint('[VYBE] _syncLoudnessToVolume: $e');
    }
  }

  Future<void> setDspMode(DspMode mode) async {
    _dspMode = mode;
    await _persistence.saveDspMode(mode);
    await _applyDspNow(mode);
    // Check volume IMMEDIATELY, no debounce
    await _syncLoudnessToVolume(_player.volume, immediate: true);
  }

  // ─── Playback Controls ─────────────────────────────────────────────────────

  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('[VYBE] play: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[VYBE] pause: $e');
    }
  }

  Future<void> togglePlayPause() async {
    _player.playing ? await pause() : await play();
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[VYBE] seek: $e');
    }
  }

  Future<void> skipNext() async {
    try {
      await _player.seekToNext();
    } catch (e) {
      debugPrint('[VYBE] skipNext: $e');
    }
  }

  Future<void> skipPrevious() async {
    try {
      if (currentState.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
      } else {
        await _player.seekToPrevious();
      }
    } catch (e) {
      debugPrint('[VYBE] skipPrevious: $e');
    }
  }

  Future<void> setVolume(double v) async {
    try {
      final nv = v.clamp(0.0, 1.0);
      await _player.setVolume(nv);
      await _syncLoudnessToVolume(nv, immediate: false);
    } catch (_) {}
  }

  Future<void> toggleShuffle() async {
    try {
      final next = !_player.shuffleModeEnabled;
      await _player.setShuffleModeEnabled(next);
      _persistence.saveShuffle(next);
    } catch (e) {
      debugPrint('[VYBE] shuffle: $e');
    }
  }

  Future<void> setLoopModeExternal(LoopMode mode) async {
    await _player.setLoopMode(mode);
    _persistence.saveLoopMode(mode);
  }

  // ─── Queue Management ──────────────────────────────────────────────────────

  Future<void> loadQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;

    // Gate on JustAudioBackground being ready. Without this, calling play()
    // before JustAudioBackground.init() completes throws:
    //   LateInitializationError: Field '_audioHandler' has not been initialized.
    try {
      await justAudioBackgroundReady.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw TimeoutException('JustAudioBackground init timed out'),
      );
    } catch (e) {
      debugPrint('[VYBE] loadQueue blocked — background service not ready: $e');
      return;
    }

    // Build sources — skip any track that can't produce a valid source.
    final sources = <AudioSource>[];
    final validTracks = <Track>[];
    for (final t in tracks) {
      final src = _tryBuildSource(t);
      if (src != null) {
        sources.add(src);
        validTracks.add(t);
      }
    }
    if (sources.isEmpty) return;

    _queue
      ..clear()
      ..addAll(validTracks);

    final safeStart = startIndex.clamp(0, validTracks.length - 1);
    _currentIndex = safeStart;

    try {
      await _playlist.clear();
      await _playlist.addAll(sources);
      await _player.seek(Duration.zero, index: safeStart);
      await _player.play();
    } catch (e) {
      debugPrint('[VYBE] loadQueue error: $e');
    }
  }

  Future<void> playTrack(Track track) async {
    final idx = _queue.indexWhere((t) => t.id == track.id);
    if (idx >= 0) {
      try {
        await _player.seek(Duration.zero, index: idx);
        await _player.play();
      } catch (e) {
        debugPrint('[VYBE] playTrack seek: $e');
      }
      return;
    }
    await loadQueue([track]);
  }

  Future<void> addToQueue(Track track) async {
    final src = _tryBuildSource(track);
    if (src == null) return;
    _queue.add(track);
    try {
      await _playlist.add(src);
    } catch (e) {
      debugPrint('[VYBE] addToQueue: $e');
    }
  }

  Future<void> addNext(Track track) async {
    final src = _tryBuildSource(track);
    if (src == null) return;
    final at = _currentIndex + 1;
    _queue.insert(at, track);
    try {
      await _playlist.insert(at, src);
    } catch (e) {
      debugPrint('[VYBE] addNext: $e');
    }
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    try {
      await _playlist.removeAt(index);
    } catch (e) {
      debugPrint('[VYBE] removeFromQueue: $e');
    }
  }

  // ─── EQ ────────────────────────────────────────────────────────────────────
  Future<AndroidEqualizerParameters?> getEqualizerParameters() async {
    try {
      return await _equalizer?.parameters;
    } catch (_) {
      return null;
    }
  }

  // Override setEqualizerBandGain to prevent writes in transparent mode
  Future<void> setEqualizerBandGain(int bandIndex, double gainDb) async {
    if (bandIndex >= 0 && bandIndex < _currentEqGains.length) {
      _currentEqGains[bandIndex] = gainDb;
    }
    // Only write to hardware if in enhanced mode AND EQ is enabled
    if (_dspMode != DspMode.enhanced) return;

    try {
      final params = await _equalizer?.parameters;
      if (params == null || bandIndex >= params.bands.length) return;
      await params.bands[bandIndex].setGain(gainDb);
    } catch (e) {
      debugPrint('[VYBE] EQ band: $e');
    }
  }

  Future<void> applyEqGains(List<double> gains) async {
    _currentEqGains = List<double>.from(gains);
    // FIX: guard — only write when EQ effect is actually active.
    if (_dspMode != DspMode.enhanced) return;
    try {
      final params = await _equalizer?.parameters;
      if (params == null) return;
      for (int i = 0; i < params.bands.length && i < gains.length; i++) {
        await params.bands[i].setGain(gains[i]);
      }
    } catch (e) {
      debugPrint('[VYBE] applyEqGains: $e');
    }
  }

  /// Apply the current enhanced EQ gains to the platform equalizer.
  Future<void> _applyEnhancedEq() async {
    if (_dspMode != DspMode.enhanced) return;
    try {
      final params = await _equalizer?.parameters;
      if (params == null) return;

      final bandCount = params.bands.length;
      final gains = List<double>.generate(bandCount, (i) {
        if (i < _currentEqGains.length) return _currentEqGains[i];
        if (i < enhancedEqDefaultGains.length) return enhancedEqDefaultGains[i];
        return 0.0;
      });

      for (int i = 0; i < bandCount && i < params.bands.length; i++) {
        await params.bands[i].setGain(gains[i]);
      }

      _currentEqGains = List<double>.from(gains);
    } catch (e) {
      debugPrint('[VYBE] _applyEnhancedEq: $e');
    }
  }

  // ─── Internal helpers ──────────────────────────────────────────────────────

  AudioSource? _tryBuildSource(Track track) {
    try {
      final tag = MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        artUri:
            track.albumArtUri != null ? Uri.tryParse(track.albumArtUri!) : null,
        duration: track.duration,
      );
      if (track.isLocal &&
          track.localPath != null &&
          track.localPath!.isNotEmpty) {
        final uri = Uri.tryParse(track.localPath!);
        if (uri == null) return null;
        return AudioSource.uri(uri, tag: tag);
      }
      return null;
    } catch (e) {
      debugPrint('[VYBE] _tryBuildSource skipped "${track.title}": $e');
      return null;
    }
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    // Cancel debounce timer on cleanup
    _loudnessDebounceTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    await _stateController.close();
    await _player.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Save the current playback state
      _persistence.savePlaybackState(_player.playing);
    } else if (state == AppLifecycleState.resumed) {
      // Optionally restore playback state if needed
    }
  }

  // Provide a getter/tear-off so the UI can cycle loop modes.
  Future<void> Function() get cycleLoopMode => _cycleLoopMode;

  Future<void> _cycleLoopMode() async {
    try {
      final current = _player.loopMode;
      final next = current == LoopMode.off
          ? LoopMode.all
          : current == LoopMode.all
              ? LoopMode.one
              : LoopMode.off;
      await setLoopModeExternal(next);
    } catch (e) {
      debugPrint('[VYBE] cycleLoopMode: $e');
    }
  }
}
