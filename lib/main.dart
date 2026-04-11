// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app.dart';
import 'core/app_globals.dart';
import 'data/models/track.dart';
import 'data/models/playlist.dart';
import 'data/repositories/playlist_repo.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
  };

  // UncontrolledProviderScope shares [appContainer] with the widget tree.
  // This lets _bootstrap() update providers (e.g. permissionGrantedProvider)
  // from outside the tree without needing a BuildContext or WidgetRef.
  runApp(
    UncontrolledProviderScope(
      container: appContainer,
      child: const VybeApp(),
    ),
  );

  // Defer bootstrap to post-frame so the Activity is fully alive:
  //   • Permission dialogs require a foregrounded Activity.
  //   • JustAudioBackground needs the Activity to bind its service.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(_bootstrap()),
  );
}

Future<void> _bootstrap() async {
  try {
    // ── Permissions ──────────────────────────────────────────────────────────
    // Request first. On success, flip permissionGrantedProvider → true.
    // Library FutureProviders watch this flag and re-run immediately,
    // so songs/albums/artists load right after the user taps Allow.
    bool granted = false;
    try {
      granted = await _requestPermissions();
    } catch (e) {
      debugPrint('Permission request skipped (non-fatal): $e');
    }
    appContainer.read(permissionGrantedProvider.notifier).state = granted;

    // ── Hive ─────────────────────────────────────────────────────────────────
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TrackAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(VybePlaylistAdapter());
    }
    await PlaylistRepository.openBox();

    // ── JustAudioBackground ──────────────────────────────────────────────────
    // MUST complete before AudioPlayer.play() is ever called.
    // [justAudioBackgroundReady] gates play/loadQueue in VybeAudioEngine.
    // Requires MainActivity to extend AudioServiceActivity, not FlutterActivity.
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.vybe.app.channel.audio',
        androidNotificationChannelName: 'VYBE Audio',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: false,
        androidStopForegroundOnPause: true,
        notificationColor: const Color(0xFFFF1B6B),
      );
      justAudioBackgroundReady.complete();
    } catch (e) {
      debugPrint('JustAudioBackground.init failed: $e');
      // Complete with error so engine surfaces it rather than hanging forever.
      if (!justAudioBackgroundReady.isCompleted) {
        justAudioBackgroundReady.completeError(e);
      }
    }

    // ── System UI ────────────────────────────────────────────────────────────
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    unawaited(SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    ));
  } catch (e, s) {
    debugPrint('Bootstrap failed: $e');
    debugPrintStack(stackTrace: s);
  }
}

/// Returns true when at least one required permission is granted.
Future<bool> _requestPermissions() async {
  final results = await [Permission.audio, Permission.storage].request();

  final granted = results[Permission.audio]?.isGranted == true ||
      results[Permission.storage]?.isGranted == true;

  if (!granted) {
    final permanentlyDenied =
        results[Permission.audio]?.isPermanentlyDenied == true ||
            results[Permission.storage]?.isPermanentlyDenied == true;
    if (permanentlyDenied) await openAppSettings();
  }

  return granted;
}

void unawaited(Future<void> future) => future.ignore();
