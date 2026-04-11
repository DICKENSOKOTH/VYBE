// lib/core/app_globals.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared ProviderContainer.
///
/// Using [UncontrolledProviderScope] in main.dart instead of [ProviderScope]
/// lets bootstrap code (which runs outside the widget tree) update providers
/// directly — e.g. to signal that permissions were granted.
final appContainer = ProviderContainer();

/// Flips to `true` once audio/storage permission is granted.
///
/// Watched by [localTracksProvider], [localAlbumsProvider], and
/// [localArtistsProvider] — changing it from false → true causes those
/// FutureProviders to re-run and query the device library.
final permissionGrantedProvider = StateProvider<bool>((ref) => false);

/// Completes once JustAudioBackground.init() finishes successfully.
///
/// [VybeAudioEngine.loadQueue] awaits this before calling
/// [AudioPlayer.play()] to prevent the LateInitializationError that
/// occurs when the background handler hasn't been wired up yet.
final justAudioBackgroundReady = Completer<void>();
