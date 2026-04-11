# android/app/proguard-rules.pro
# VYBE ProGuard Rules

# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── just_audio / audio_service ───────────────────────────────────────────────
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**

# ── VYBE platform channels ───────────────────────────────────────────────────
-keep class com.vybe.app.** { *; }

# ── Android AudioEffect subclasses ───────────────────────────────────────────
-keep class android.media.audiofx.** { *; }
-keep class android.media.AudioMixerAttributes { *; }
-keep class android.media.AudioMixerAttributes$Builder { *; }

# ── Hive ─────────────────────────────────────────────────────────────────────
-keep class * extends com.google.flatbuffers.Table { *; }
-keep class * implements io.hive.** { *; }

# ── Firebase ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── General ──────────────────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn javax.**
-dontwarn org.slf4j.**
