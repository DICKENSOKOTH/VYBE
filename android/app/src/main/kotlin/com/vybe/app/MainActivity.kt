// android/app/src/main/kotlin/com/vybe/app/MainActivity.kt
package com.vybe.app

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Must extend AudioServiceActivity (not FlutterActivity) so that
 * just_audio_background can bind its MediaBrowserService and initialise
 * _audioHandler. Using plain FlutterActivity causes:
 *
 *   IllegalStateException: The Activity class declared in your
 *   AndroidManifest.xml is wrong or has not provided the correct FlutterEngine.
 *
 * which leaves _audioHandler uninitialised and throws LateInitializationError
 * on the first AudioPlayer.play() call.
 */
class MainActivity : AudioServiceActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register all VYBE platform channels
        BitPerfectChannel(this, flutterEngine.dartExecutor.binaryMessenger).register()
        AudioEffectsChannel(this, flutterEngine.dartExecutor.binaryMessenger).register()
        HiResAudioChannel(this, flutterEngine.dartExecutor.binaryMessenger).register()
    }
}