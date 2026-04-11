// lib/core/providers.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/vybe_audio_engine.dart';
import '../data/repositories/lyrics_repo.dart';
import '../data/repositories/playlist_repo.dart';
import '../data/models/track.dart';
import '../data/models/lyrics_line.dart';
import '../data/models/playlist.dart';
import 'dynamic_palette_notifier.dart';

// ─── Audio Engine ──────────────────────────────────────────────────────────────

final audioEngineProvider = Provider<VybeAudioEngine>((ref) {
  final engine = VybeAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

// ─── Lyrics ────────────────────────────────────────────────────────────────────

final lyricsRepoProvider = Provider<LyricsRepository>((ref) {
  final repo = LyricsRepository();
  repo.geniusApiKey    = ref.watch(geniusApiKeyProvider).trim().isEmpty ? null
      : ref.watch(geniusApiKeyProvider).trim();
  repo.anthropicApiKey = ref.watch(anthropicApiKeyProvider).trim().isEmpty ? null
      : ref.watch(anthropicApiKeyProvider).trim();
  return repo;
});

// ─── Playlists ─────────────────────────────────────────────────────────────────

final playlistRepoProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository();
});

final playlistsProvider = StreamProvider<List<VybePlaylist>>((ref) {
  final repo = ref.watch(playlistRepoProvider);
  final listenable = repo.listenable();
  final controller = StreamController<List<VybePlaylist>>();

  void listener() {
    if (!controller.isClosed) controller.add(repo.getAll());
  }

  listenable.addListener(listener);
  // Emit the current list immediately so the UI doesn't wait for a change event.
  controller.add(repo.getAll());

  ref.onDispose(() {
    listenable.removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

// ─── Player State ──────────────────────────────────────────────────────────────

final playerStateProvider = StreamProvider<VybePlayerState>((ref) {
  return ref.watch(audioEngineProvider).stateStream;
});

final currentTrackProvider     = Provider<Track?>((ref)        => ref.watch(playerStateProvider).value?.currentTrack);
final isPlayingProvider        = Provider<bool>((ref)          => ref.watch(playerStateProvider).value?.isPlaying ?? false);
final playerPositionProvider   = Provider<Duration>((ref)      => ref.watch(playerStateProvider).value?.position ?? Duration.zero);
final playerDurationProvider   = Provider<Duration?>((ref)     => ref.watch(playerStateProvider).value?.duration);
final playbackProgressProvider = Provider<double>((ref)        => ref.watch(playerStateProvider).value?.progress ?? 0.0);
final queueProvider            = Provider<List<Track>>((ref)   => ref.watch(playerStateProvider).value?.queue ?? []);
final activeTierProvider       = Provider<PlaybackTier>((ref)  => ref.watch(playerStateProvider).value?.activeTier ?? PlaybackTier.standard);

final lyricsProvider = FutureProvider.family<Lyrics, Track>((ref, track) async {
  return ref.watch(lyricsRepoProvider).fetchLyrics(track);
});

// ─── Dynamic Palette ────────────────────────────────────────────────────────────

final dynamicPaletteProvider = AsyncNotifierProvider<DynamicPaletteNotifier, DynamicPalette>(
  DynamicPaletteNotifier.new,
);

// ─── UI State ──────────────────────────────────────────────────────────────────

final playerExpandedProvider   = StateProvider<bool>((ref)    => false);
final bottomNavIndexProvider   = StateProvider<int>((ref)     => 0);
final equalizerEnabledProvider = StateProvider<bool>((ref)    => true);
final dspModeProvider          = StateProvider<DspMode>((ref) => DspMode.transparent);

// ─── API Keys ──────────────────────────────────────────────────────────────────

final geniusApiKeyProvider    = StateProvider<String>((ref) => '');
final anthropicApiKeyProvider = StateProvider<String>((ref) => '');