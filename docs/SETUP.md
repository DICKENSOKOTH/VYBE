# VYBE — Setup Guide

## Prerequisites

| Tool | Minimum version | Check |
|---|---|---|
| Flutter SDK | 3.19.0 | `flutter --version` |
| Dart SDK | 3.3.0 | `dart --version` |
| Android SDK | API 24 (Android 7.0) | Android Studio SDK Manager |
| Java | 17 | `java -version` |
| Gradle | 8.x | bundled with project |

---

## 1. Clone and install

```bash
git clone <your-repo-url> vybe
cd vybe
flutter pub get
```

---

## 2. Add fonts

The fonts are not included in the repository (binary files, not source). Download them from Google Fonts and place them in `assets/fonts/`:

**Plus Jakarta Sans** (used as `VybeSans`):
- `PlusJakartaSans-Regular.ttf`
- `PlusJakartaSans-Medium.ttf`
- `PlusJakartaSans-SemiBold.ttf`
- `PlusJakartaSans-Bold.ttf`
- `PlusJakartaSans-ExtraBold.ttf`

Download: https://fonts.google.com/specimen/Plus+Jakarta+Sans

**Syne** (used as `VybeDisplay`):
- `Syne-Bold.ttf`
- `Syne-ExtraBold.ttf`

Download: https://fonts.google.com/specimen/Syne

The `assets/fonts/` directory must exist (create it if not present). The `pubspec.yaml` already references these paths.

---

## 3. Android setup

### Minimum SDK
The app targets Android 7.0 (API 24) and above. No changes needed for standard devices.

### Permissions
Declared in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission
  android:name="android.permission.READ_EXTERNAL_STORAGE"
  android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

`READ_MEDIA_AUDIO` is the Android 13+ replacement for `READ_EXTERNAL_STORAGE`. The app requests the right permission at runtime depending on API level — no manual change needed.

### Build configuration
The project uses Kotlin DSL (`build.gradle.kts`). If you see Groovy syntax errors, ensure you are opening the project with the `.kts` files, not legacy `.gradle` files.

---

## 4. Run

**Debug (hot reload enabled):**
```bash
flutter run
```

**Release build (for testing performance):**
```bash
flutter run --release
```

**Build APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Build App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```

---

## 5. First launch

1. The app opens on the Library screen.
2. A permission dialog requests access to audio files. Tap **Allow**.
3. The Songs, Albums, and Artists tabs populate immediately.
4. Tap any song to begin playback.

---

## 6. Optional: Lyrics API keys

For expanded lyrics coverage, add API keys in **Settings → Lyrics Sources**.

### Genius
1. Go to https://genius.com/api-clients
2. Create a new API client (any name and URL)
3. Copy the **Client Access Token**
4. Paste it into the Genius API Key field in Settings

### Anthropic (AI fallback)
1. Go to https://console.anthropic.com
2. Create an API key
3. Paste it into the Anthropic Key field in Settings

The AI fallback is only called if LRCLIB and Genius both return no results for a track.

---

## 7. Kotlin platform channels

Three Kotlin files in `android/app/src/main/kotlin/com/vybe/app/` implement native capabilities:

| File | Channel | Purpose |
|---|---|---|
| `HiResAudioChannel.kt` | `com.vybe.app/hi_res_audio` | Detect native sample rate |
| `AudioEffectsChannel.kt` | `com.vybe.app/audio_effects` | System audio effects |
| `BitPerfectChannel.kt` | `com.vybe.app/bit_perfect` | USB DAC exclusive mode |
| `MainActivity.kt` | — | Registers all three channels |

These files are already in the repository. No setup needed unless you are modifying native code.

---

## 8. Hive code generation

The `Track` and `VybePlaylist` Hive adapters are pre-generated (`track.g.dart`, `playlist.g.dart`) and committed to the repository. You do not need to run `build_runner` for a clean install.

If you add or change `@HiveType` / `@HiveField` annotations, regenerate with:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 9. Common issues

### Songs tab empty after permission grant
The `localTracksProvider` is reactive — it watches `permissionGrantedProvider`. If the permission was already granted on a previous install and the provider wasn't flipped, add a manual invalidation. In practice this resolves itself on fresh install.

### `MissingPluginException` on platform channels
This means `MainActivity.kt` did not register the channels correctly, or the app was hot-restarted without a full rebuild after Kotlin changes. Run `flutter run` (not hot restart) to rebuild the native code.

### `JustAudioBackground.init failed`
The activity must extend `FlutterActivity` (not `Activity` or `AppCompatActivity`) for `just_audio_background` to find the correct `FlutterEngine`. Check `MainActivity.kt`.

### Fonts not loading / text shows system font
Verify the font files are in `assets/fonts/` with exact filenames matching `pubspec.yaml`. Font filenames are case-sensitive on Android.

### Build fails with Kotlin DSL error
Ensure you do not have both `build.gradle` and `build.gradle.kts` in the same directory. The project uses `.kts` exclusively — delete any legacy `.gradle` files.
