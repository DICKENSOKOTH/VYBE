# VYBE — Design Decisions

A record of the significant technical choices made during development, and why.

---

## Local-only, no streaming

YouTube streaming was prototyped and then removed. The removal was deliberate:

- Stream resolution relies on reverse-engineered YouTube APIs that break on every YouTube client update. Maintaining it is a permanent maintenance burden.
- ExoPlayer stalls on some stream URLs with no recoverable error — the failure mode is unpredictable.
- Local playback is the core use case. Streaming adds complexity without improving it.
- App size stays under 200 MB without the youtube_explode_dart and related HTTP machinery.

The search tab was removed at the same time. Search is now inline in the Library header, filtering local files only.

---

## just_audio over audio_service directly

`just_audio_background` is a thin wrapper around `audio_service` that handles the `FlutterEngine` wiring automatically. Using `audio_service` directly requires manually subclassing `BaseAudioHandler`, which adds ~200 lines of boilerplate with no practical benefit at this scale.

The tradeoff: `just_audio_background` is less flexible (cannot implement custom media button behaviour). This is acceptable — VYBE only needs play/pause/skip from the lockscreen, which `just_audio_background` handles.

---

## Riverpod over BLoC / Provider / GetX

Riverpod was chosen because:
- `FutureProvider.family` handles the lyrics-per-track pattern with zero boilerplate.
- `StreamProvider` turns the `BehaviorSubject` stream from the audio engine into a widget-reactive value in one line.
- `AsyncNotifier` for `DynamicPaletteNotifier` gives async build with automatic loading/error states.
- No `BuildContext` required to read providers — the engine can be read from anywhere.
- Provider invalidation (re-running `localTracksProvider` when permission is granted) is one line.

---

## Hive over SQLite / Drift

Playlist data is a list of ordered string IDs — essentially a JSON array. SQLite is the right tool for relational queries; Hive is the right tool for typed key-value objects. The playlist domain has no joins, no aggregations, and no complex queries. Hive reads are synchronous and O(1) by key — no async overhead on the main thread.

The `playlistsProvider` streams Hive's `ValueListenable` directly, giving reactive UI updates without polling or manual `setState`.

---

## Two DSP modes instead of one

Early builds had a single "Enhanced" mode and no way to turn it off. Testing on lossless FLAC files revealed the EQ curve added colouration that was clearly audible compared to bypassed playback. The decision was made to make the bypass mode a first-class option called "Transparent" — a concept borrowed from audiophile DAC firmware.

The names were chosen carefully. "Hi-Res" was considered but rejected because it implies something about the file format, not the processing chain. "Transparent" correctly describes what happens: the processing is transparent, i.e. indistinguishable from no processing.

---

## Volume-fade DSP transition

The first implementation dipped `AndroidLoudnessEnhancer.setTargetGain` to 0 before calling `setEnabled`. This did not work — the click was still audible because `setEnabled` is an instantaneous hardware register write on the Android `AudioEffect` API, and the gain dip happened in a different part of the processing chain that didn't cover the moment of the switch.

The correct solution is to fade the ExoPlayer software volume (`AudioPlayer.setVolume`) to zero. This is a gain applied in the ExoPlayer mixer before `AudioTrack`, so when it reaches zero the signal is genuinely silent all the way down the chain. The `setEnabled` calls at that point produce no audible artifact.

240 ms total (120 ms out + 120 ms in) was tuned by listening. Below 80 ms the fade is not noticeable but the timing is too tight for the effect engine to settle reliably. Above 300 ms the user perceives a pause. 240 ms is the same duration Tidal uses.

---

## Stall watchdog instead of ExoPlayer retry

ExoPlayer provides a `LoadControl` interface for tuning buffering behaviour, but it has no hook for "decoder produced no output for N seconds while reporting ready". The only documented recovery for this state is seeking.

A watchdog timer that polls `player.position` every 1500 ms and seeks forward 200 ms on a frozen position was chosen because:
- It requires no native code.
- It is invisible to the user — 200 ms is below the threshold for perceived discontinuity.
- It handles the only known failure mode (malformed VBR MP3 frame) without modifying the broader playback logic.

1500 ms polling interval ensures the watchdog catches stalls quickly (typically within 1.5–3 s) without adding meaningful CPU overhead.

---

## AndroidEqualizer over AudioEffectsChannel for DSP

Android has two places to apply audio effects:
1. Inside an ExoPlayer `AudioPipeline` — `AndroidEqualizer`, `AndroidLoudnessEnhancer`
2. At the system mixer via `AudioEffect` subclasses — `BassBoost`, `Virtualizer`, `LoudnessEnhancer`

Effects at the system mixer level are **not** bounded by Android's software volume stack. They are applied after the media volume control in the signal path. At high volumes this can push the signal above the headphone amplifier's clipping threshold, which is audible as distortion and can damage speakers.

All DSP in Enhanced mode uses option 1 exclusively. The `AudioEffectsChannel` Kotlin bridge (option 2) is present in the codebase for future experimentation but is not called from the current Enhanced mode implementation.

---

## DynamicPalette: vibrant over dominant

`palette_generator` exposes both `dominantColor` (most pixels) and `vibrantColor` (most saturated). For album art, dominant is often a dark background or white space — not visually interesting as an accent. Vibrant is always the colour that jumps out of the artwork. For a music player UI, vibrant is the correct choice for glow, borders, and highlights.

The background tint uses vibrant at 25% HSL lightness (darkened while preserving hue) so it is visually present without washing out text. This is a common pattern in Apple Music and Spotify's "Now Playing" blur backgrounds.

---

## No word-level karaoke

LRCLIB's synced lyrics format (`.lrc`) provides one timestamp per line, not per word. Word-level timestamps exist in some streaming service formats (Spotify's internal format, Apple Music's TTML) but are not available from any free public API. Implementing line-level auto-scroll with binary search gives the same felt quality as most commercial players.

---

## No Firebase / cloud sync

Adding Firebase would require:
- Google Play Services dependency (not present on all Android devices)
- Authentication (account system, privacy policy)
- Cloud Functions or Firestore rules
- Significantly increased binary size

The only state that benefits from sync is playlists. This is not worth the complexity for a local-first player. Playlists could be exported to JSON in a future version for manual backup.
