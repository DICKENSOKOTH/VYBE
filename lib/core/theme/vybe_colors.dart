// lib/core/theme/vybe_colors.dart
import 'package:flutter/material.dart';

abstract class VybeColors {
  static const background        = Color(0xFF080810);
  static const surface           = Color(0xFF0F0F1A);
  static const surfaceElevated   = Color(0xFF15152A);
  static const surfaceGlass      = Color(0x1AFFFFFF);
  static const surfaceGlassHigh  = Color(0x26FFFFFF);
  static const border            = Color(0x1AFFFFFF);
  static const borderAccent      = Color(0x33FF1B6B);

  static const vybeStart  = Color(0xFFFF1B6B);
  static const vybeMid    = Color(0xFFFF3CAC);
  static const vybeEnd    = Color(0xFFFF6B35);
  static const vybeDeep   = Color(0xFF8B1FFF);

  static const vybeGradient = LinearGradient(
    colors: [vybeStart, vybeMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const vybeGradientFull = LinearGradient(
    colors: [vybeStart, vybeMid, vybeEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  static const playerGradient = LinearGradient(
    colors: [Color(0xFF0A0A18), Color(0xFF12082A), Color(0xFF0A0A18)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const textPrimary    = Color(0xFFFFFFFF);
  static const textSecondary  = Color(0xB3FFFFFF);
  static const textTertiary   = Color(0x66FFFFFF);
  static const textAccent     = vybeStart;

  static const success       = Color(0xFF1DB954);
  static const warning       = Color(0xFFFFB800);
  static const error         = Color(0xFFFF3B30);

  static const tierStandard  = Color(0xFF888888);
  static const tierHiRes     = Color(0xFF00D4FF);
  static const tierBitPerfect = Color(0xFFFFD700);

  static const waveformActive   = vybeStart;
  static const waveformInactive = Color(0x33FFFFFF);
}
// DynamicPalette lives in lib/core/dynamic_palette_notifier.dart
