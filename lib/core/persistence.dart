// lib/core/persistence.dart
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/vybe_audio_engine.dart';

class VybePersistence {
  static const _kLoopMode  = 'vybe_loop_mode';
  static const _kShuffle   = 'vybe_shuffle';
  static const _kDspMode   = 'vybe_dsp_mode';

  final SharedPreferences _prefs;
  VybePersistence._(this._prefs);

  static Future<VybePersistence> load() async {
    final prefs = await SharedPreferences.getInstance();
    return VybePersistence._(prefs);
  }

  Future<void> saveLoopMode(LoopMode mode) => _prefs.setString(_kLoopMode,
    switch (mode) { LoopMode.all => 'all', LoopMode.one => 'one', _ => 'off' });

  Future<void> saveShuffle(bool enabled) => _prefs.setBool(_kShuffle, enabled);

  Future<void> saveDspMode(DspMode mode) => _prefs.setString(
    _kDspMode, mode == DspMode.enhanced ? 'enhanced' : 'transparent');

  LoopMode get loopMode => switch (_prefs.getString(_kLoopMode) ?? 'off') {
    'all' => LoopMode.all,
    'one' => LoopMode.one,
    _     => LoopMode.off,
  };

  bool get shuffle  => _prefs.getBool(_kShuffle) ?? false;

  DspMode get dspMode => _prefs.getString(_kDspMode) == 'enhanced'
      ? DspMode.enhanced
      : DspMode.transparent;

  Future<void> savePlaybackState(bool isPlaying) async {
    // Save the playback state (e.g., to shared preferences or a file)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('playbackState', isPlaying);
  }

  Future<bool> loadPlaybackState() async {
    // Load the playback state
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('playbackState') ?? false; // Default to false
  }
}
