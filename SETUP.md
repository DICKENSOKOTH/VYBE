# VYBE — Setup & Build Guide
### Flutter + Android 16 (API 36) · Tested on Android 16

---

## 1. Prerequisites

```bash
# Verify Flutter is installed and healthy
flutter doctor

# Required Flutter version: 3.19+
flutter --version

# Required Dart: 3.3+
dart --version
```

---

## 2. Create the Flutter project

```bash
# Create project with the exact package name
flutter create --org com.vybe --project-name vybe vybe

# Navigate into it
cd vybe
```

Then **copy all the generated files** from this repo into your project folder,
overwriting the defaults. The structure should match exactly.

---

## 3. Get fonts

VYBE uses two font families. Download them free from Google Fonts:

```bash
# Create font directory
mkdir -p assets/fonts assets/images assets/animations

# Fonts to download:
# 1. Plus Jakarta Sans → https://fonts.google.com/specimen/Plus+Jakarta+Sans
#    Files needed: PlusJakartaSans-Regular.ttf, Medium, SemiBold, Bold, ExtraBold
#
# 2. Syne → https://fonts.google.com/specimen/Syne
#    Files needed: Syne-Bold.ttf, Syne-ExtraBold.ttf
```

Place all `.ttf` files in `assets/fonts/`.

---

## 4. Install dependencies

```bash
flutter pub get
```

### Generate Hive type adapters (for Track model)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

> ⚠️ The `Track` model has a `part 'track.g.dart'` directive.
> Run build_runner before first compile or you'll get a missing file error.
> After running it, uncomment the `Hive.registerAdapter(TrackAdapter())` line in `main.dart`.

---

## 5. Android permissions setup

The `AndroidManifest.xml` is already configured. For Android 16 (API 36),
the key permissions that matter for VYBE:

| Permission | Why |
|---|---|
| `READ_MEDIA_AUDIO` | Scan local music library (Android 13+) |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Lockscreen controls, background playback |
| `MODIFY_AUDIO_SETTINGS` | Bit-Perfect DAC control |
| `WAKE_LOCK` | Keep CPU alive during playback |

---

## 6. Firebase setup (optional — for cloud playlists)

Firebase is optional. Without it, playlists save locally to Hive only.

To enable Firebase:
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure (follow prompts — select Android)
flutterfire configure
```

This generates `android/app/google-services.json` and `lib/firebase_options.dart`.

Until you do this, comment out Firebase imports in `pubspec.yaml` and `main.dart`.

---

## 7. Run on Android 16

```bash
# Ensure your Android 16 device is connected and visible
adb devices

# Run debug build
flutter run

# Run with verbose logging (good for audio debugging)
flutter run --verbose

# Run release build (tests true performance)
flutter run --release
```

### First launch checklist
- [ ] Grant audio permission (tap Allow when prompted)
- [ ] Library tab shows your local music files
- [ ] Tap a track — player opens and music plays
- [ ] Search tab — paste a YouTube URL and hit Play
- [ ] Lockscreen shows player controls

---

## 8. Platform channel verification

To confirm the Kotlin channels are working, run with:

```bash
flutter run --verbose 2>&1 | grep -E "VYBE_|BitPerfect|HiRes|AudioFX"
```

You should see on startup:
```
VYBE_BitPerfect: BitPerfect channel registered. API level: 36
VYBE_HiRes: HiRes channel registered
VYBE_AudioFX: AudioEffects channel registered — BassBoost: true, Virtualizer: true, LoudnessEnhancer: true
```

If you see `false` for any effect, it means your test device's audio HAL
doesn't support it — that's fine, VYBE handles it gracefully.

---

## 9. API Keys (optional — get these when ready)

### LRCLIB (no key needed)
Works out of the box. No registration.

### Genius (for lyrics fallback)
1. Go to https://genius.com/api-clients
2. Create an app → copy the Client Access Token
3. In the app: Settings → Lyrics → Enter Genius API key

### Musixmatch (for synced lyrics fallback)
1. https://developer.musixmatch.com/
2. Free tier: 2000 requests/day
3. Set in app settings

### Anthropic (AI lyrics generation)
1. https://console.anthropic.com/
2. Free tier available
3. Set in app settings

For now, **LRCLIB alone covers ~80% of tracks** — you can launch without any keys.

---

## 10. File structure reference

```
vybe/
├── lib/
│   ├── main.dart                          ← Entry point
│   ├── app.dart                           ← Root widget + engine init
│   ├── core/
│   │   ├── providers.dart                 ← All Riverpod providers
│   │   └── theme/
│   │       ├── app_theme.dart             ← Material3 dark theme
│   │       └── vybe_colors.dart           ← Design tokens
│   ├── audio/
│   │   ├── vybe_audio_engine.dart         ← Core player (just_audio wrapper)
│   │   ├── streaming/
│   │   │   └── youtube_stream_service.dart ← YT stream resolver + adaptive quality
│   │   └── platform_channels/
│   │       └── bit_perfect_channel.dart   ← Dart side of all 3 method channels
│   ├── data/
│   │   ├── models/
│   │   │   ├── track.dart                 ← Track model (Hive)
│   │   │   └── lyrics_line.dart           ← Lyrics + LRC parser
│   │   └── repositories/
│   │       └── lyrics_repo.dart           ← LRCLIB → Genius → MXM → AI pipeline
│   ├── features/
│   │   ├── home/home_screen.dart          ← Root screen + nav
│   │   ├── player/
│   │   │   ├── now_playing_screen.dart    ← Full player UI
│   │   │   └── mini_player.dart           ← Persistent bottom bar
│   │   ├── library/library_screen.dart   ← Local music scanner + track list
│   │   ├── search/search_screen.dart     ← YouTube URL paste + stream
│   │   ├── playlists/playlists_screen.dart
│   │   └── settings/settings_screen.dart ← Tiers, DSP, stream quality
│   └── widgets/
│       └── glassmorphic_card.dart        ← GlassCard + WaveformBars
└── android/
    └── app/src/main/kotlin/com/vybe/app/
        ├── MainActivity.kt               ← Registers all channels
        ├── BitPerfectChannel.kt          ← Android 14+ DAC exclusive
        ├── AudioEffectsChannel.kt        ← BassBoost + Virtualizer + LoudnessEnhancer
        └── HiResAudioChannel.kt          ← Device capability detection
```

---

## 11. Known issues + solutions

### `track.g.dart` missing
→ Run `flutter pub run build_runner build`

### "Permission denied" on file scan
→ Uninstall the app from device, reinstall (clears stale permission state on Android 14+)

### YouTube stream fails
→ youtube_explode_dart occasionally needs the `DenoEJSSolver` for JS challenge videos.
   For most tracks `YoutubeApiClient.ios` + `YoutubeApiClient.androidVr` works fine.
   If you hit consistent failures, see: https://github.com/Hexer10/youtube_explode_dart

### Bit-Perfect mode not available
→ Requires Android 14+ (API 34+). Android 16 ✓. The Settings screen shows current tier.

### Build fails: `kotlin_version` not found
→ Add to `android/build.gradle`:
   ```groovy
   ext.kotlin_version = '1.9.10'
   ```

---

## 12. What's ready vs Phase 2

### ✅ Ready in this foundation
- Local music library (scan + play)
- YouTube streaming (ad-free, no account)
- Adaptive stream quality (Auto / Low / Standard / High / Ultra)
- 10-band EQ via `just_audio`'s `AndroidEqualizer`
- Bass boost + 3D surround + loudness via platform channel
- Bit-Perfect mode (Android 14+) via platform channel
- Hi-Res detection (Tier B) via platform channel
- Lyrics: LRCLIB (synced LRC) + Genius + Musixmatch + AI generation
- LRC karaoke sync (ms-accurate line highlighting)
- Background playback + lockscreen controls
- Glassmorphic UI — Liquid Dark design system
- Animated waveform bars (logo identity)
- Mini player with progress bar
- Full Now Playing screen with seek bar

### 🔜 Phase 2
- EQ frequency curve visualizer (fl_chart)
- Beat-reactive background (FFT analysis)
- Waveform seek bar (just_waveform)
- Firebase cloud playlist sync
- Google/Apple Sign-In
- DAC detection popup dialog
- Playlist creation + management
- Album / Artist views
- Dynamic album art color extraction (palette_generator)
- Word-level karaoke highlighting
- SoundCloud streaming
