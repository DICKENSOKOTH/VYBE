# VYBE — Feel Every Frequency

A local-first Android music player built with Flutter. No accounts, no streaming, no ads. Just your music, played properly.

---

## Features

**Library**
- Songs, Albums, Artists tabs with staggered entrance animations
- Inline search — filters across title, artist, and album simultaneously
- Long-press any song for context menu: Play Next, Add to Queue, Add to Playlist
- Album detail view with artwork, track list, play and shuffle
- Artist detail view with all songs, play all and shuffle

**Playlists**
- Create, rename, and delete playlists
- Add songs from the library long-press menu
- Reorder tracks with drag handles
- Swipe to remove individual tracks

**Now Playing**
- Dynamic background theming — extracts the album art palette on every track change
- Album art glow colour follows the track
- Synced lyrics with auto-scroll (LRCLIB → Genius → AI fallback)
- Loop one / loop all / shuffle with persistent state
- Back button collapses the player; second press exits the app

**Audio Engine**
- Two real, audibly different modes selectable from Settings:
  - **Transparent** — zero processing, raw PCM, for FLAC/WAV/ALAC
  - **Enhanced** — 10-band EQ + loudness curve, for MP3/AAC
- Engine switches use a 240 ms software volume fade (no click or pop)
- 10 EQ presets: VYBE, Flat, Bass Boost, Treble, Vocal, Rock, Electronic, Hip-Hop, Classical, Jazz
- Stall watchdog auto-recovers from ExoPlayer decoder stalls caused by malformed audio frames
- Lockscreen controls and Android media notification

**Settings**
- Engine selector with live switching
- Genius API key for expanded lyrics catalogue
- Anthropic API key for AI-generated lyrics fallback
- Persists: engine mode, loop mode, shuffle state

---

## Tech Stack

| Layer | Choice |
|---|---|
| Language | Dart / Flutter |
| State | Riverpod (AsyncNotifier, StreamProvider, StateProvider) |
| Audio engine | just_audio + just_audio_background |
| Local library | on_audio_query |
| Storage | Hive (playlists, tracks) + SharedPreferences (settings) |
| Dynamic theming | palette_generator |
| Lyrics | LRCLIB API (free, synced), Genius API (optional), Anthropic API (optional) |
| Permissions | permission_handler |

---

## Project Structure

```
lib/
├── main.dart                          # Parallel init: Hive + JustAudioBackground
├── app.dart                           # VybeApp, engine init post-frame
│
├── audio/
│   ├── vybe_audio_engine.dart         # Core player, DSP modes, stall watchdog
│   └── platform_channels/
│       ├── bit_perfect_channel.dart   # Hi-Res / Bit-Perfect Kotlin bridge
│
├── core/
│   ├── providers.dart                 # All Riverpod providers
│   ├── persistence.dart               # SharedPreferences: loop, shuffle, DSP mode
│   ├── dynamic_palette_notifier.dart  # Album art colour extraction + cache
│   ├── app_globals.dart               # ProviderContainer, permission signal
│   └── theme/
│       ├── vybe_colors.dart           # Design tokens
│       └── app_theme.dart             # MaterialApp theme
│
├── data/
│   ├── models/
│   │   ├── track.dart + track.g.dart          # Hive typeId 0
│   │   ├── playlist.dart + playlist.g.dart    # Hive typeId 1
│   │   └── lyrics_line.dart
│   └── repositories/
│       ├── lyrics_repo.dart           # LRCLIB → Genius → AI pipeline
│       └── playlist_repo.dart         # CRUD on Hive Box<VybePlaylist>
│
├── features/
│   ├── home/
│   │   └── home_screen.dart           # 3-tab shell, back-press handling
│   ├── library/
│   │   ├── library_screen.dart        # Songs/Albums/Artists + inline search
│   │   ├── album_detail_screen.dart
│   │   └── artist_detail_screen.dart
│   ├── player/
│   │   ├── now_playing_screen.dart    # Full-screen player
│   │   └── mini_player.dart           # Persistent bottom bar
│   ├── equalizer/
│   │   └── equalizer_screen.dart      # EQ bottom sheet with presets
│   ├── playlists/
│   │   ├── playlists_screen.dart
│   │   └── playlist_detail_screen.dart
│   └── settings/
│       └── settings_screen.dart
│
└── widgets/
    └── glassmorphic_card.dart         # GlassCard + WaveformBars
```

---

## Android Platform Channels

Three Kotlin channels expose hardware audio capabilities to Dart:

| Channel | File | Purpose |
|---|---|---|
| `com.vybe.app/hi_res_audio` | `HiResAudioChannel.kt` | Detect native sample rate and Hi-Res support |
| `com.vybe.app/audio_effects` | `AudioEffectsChannel.kt` | System-level audio effect control |
| `com.vybe.app/bit_perfect` | `BitPerfectChannel.kt` | USB DAC exclusive mode (Android 14+) |

---

## Setup

### Requirements
- Flutter 3.19+
- Android SDK 24+ (Android 7.0)
- Java 17

### Fonts (not included — add manually)

Download from [Google Fonts](https://fonts.google.com) and place in `assets/fonts/`:

**Plus Jakarta Sans** (VybeSans): Regular, Medium, SemiBold, Bold, ExtraBold  
**Syne** (VybeDisplay): Bold, ExtraBold

### Install and run

```bash
flutter pub get
flutter run
```

### Permissions

On first launch the app requests `READ_MEDIA_AUDIO` (Android 13+) or `READ_EXTERNAL_STORAGE` (Android 12 and below). Grant it to load your library.

### Optional API keys

Enter in Settings → Lyrics Sources:

- **Genius** — get a free client access token at [genius.com/api-clients](https://genius.com/api-clients)
- **Anthropic** — get a key at [console.anthropic.com](https://console.anthropic.com). Used only as a last-resort lyrics fallback for obscure tracks.

---

## DSP Engine Detail

### Transparent mode
`AndroidEqualizer` and `AndroidLoudnessEnhancer` are both disabled. The decoded PCM signal travels from ExoPlayer → AudioTrack → DAC without any plugin in the chain. This is the correct mode for lossless files where you want to hear the recording exactly as mastered.

### Enhanced mode
A warm loudness curve is applied via `AndroidEqualizer` (10 bands inside the ExoPlayer `AudioPipeline`) and a modest +1.5 dB push from `AndroidLoudnessEnhancer`. Both effects operate within the pipeline and fully respect Android's system volume — there is no risk of overdriving the output.

Default EQ shape (can be adjusted in the EQ screen):

| Band | Freq | Gain |
|---|---|---|
| 1 | ~31 Hz | +4.0 dB |
| 2 | ~63 Hz | +3.0 dB |
| 3 | ~125 Hz | +1.5 dB |
| 4 | ~250 Hz | 0.0 dB |
| 5 | ~500 Hz | 0.0 dB |
| 6 | ~1 kHz | 0.0 dB |
| 7 | ~2 kHz | +1.0 dB |
| 8 | ~4 kHz | +2.0 dB |
| 9 | ~8 kHz | +2.5 dB |
| 10 | ~16 kHz | +3.0 dB |

### Engine transition
Switching modes triggers a 240 ms software volume fade (12 steps × 10 ms each direction). Effects are toggled at the silent midpoint. This eliminates the click that occurs when hardware audio effects are switched under a live signal.

---

## Known Limitations

- Local files only. No streaming.
- Lyrics sync accuracy depends on LRCLIB data quality for each track.
- Bit-Perfect mode requires Android 14+ and a USB DAC. On standard hardware it falls back to Hi-Res.
- Waveform seek bar is not implemented (ExoPlayer does not expose PCM data at the Dart layer without a native extension).

---

## License

Private. All rights reserved.