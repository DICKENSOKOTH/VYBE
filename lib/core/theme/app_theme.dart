// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vybe_colors.dart';

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: VybeColors.background,
      colorScheme: const ColorScheme.dark(
        primary: VybeColors.vybeStart,
        secondary: VybeColors.vybeMid,
        tertiary: VybeColors.vybeDeep,
        surface: VybeColors.surface,
        onPrimary: VybeColors.textPrimary,
        onSecondary: VybeColors.textPrimary,
        onSurface: VybeColors.textPrimary,
        error: VybeColors.error,
      ),
      fontFamily: 'VybeSans',
      textTheme: const TextTheme(
        // Display — Syne
        displayLarge: TextStyle(
          fontFamily: 'VybeDisplay',
          fontSize: 57,
          fontWeight: FontWeight.w800,
          color: VybeColors.textPrimary,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          fontFamily: 'VybeDisplay',
          fontSize: 45,
          fontWeight: FontWeight.w700,
          color: VybeColors.textPrimary,
          letterSpacing: -1.0,
        ),
        displaySmall: TextStyle(
          fontFamily: 'VybeDisplay',
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: VybeColors.textPrimary,
          letterSpacing: -0.5,
        ),
        // Headlines
        headlineLarge: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: VybeColors.textPrimary,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: VybeColors.textPrimary,
          letterSpacing: -0.2,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: VybeColors.textPrimary,
        ),
        // Titles
        titleLarge: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: VybeColors.textPrimary,
          letterSpacing: 0.1,
        ),
        titleMedium: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: VybeColors.textPrimary,
          letterSpacing: 0.1,
        ),
        titleSmall: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: VybeColors.textSecondary,
          letterSpacing: 0.1,
        ),
        // Body
        bodyLarge: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: VybeColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: VybeColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: VybeColors.textTertiary,
        ),
        // Label
        labelLarge: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: VybeColors.textPrimary,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontFamily: 'VybeSans',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: VybeColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
      // App bar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: VybeColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'VybeDisplay',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: VybeColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VybeColors.surface,
        indicatorColor: VybeColors.vybeStart.withAlpha(51),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: VybeColors.vybeStart, size: 24);
          }
          return const IconThemeData(color: VybeColors.textTertiary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'VybeSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: VybeColors.vybeStart,
            );
          }
          return const TextStyle(
            fontFamily: 'VybeSans',
            fontSize: 11,
            color: VybeColors.textTertiary,
          );
        }),
      ),
      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: VybeColors.vybeStart,
        inactiveTrackColor: VybeColors.surfaceGlass,
        thumbColor: VybeColors.textPrimary,
        overlayColor: VybeColors.vybeStart.withAlpha(51),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      // Icon
      iconTheme: const IconThemeData(color: VybeColors.textSecondary, size: 22),
      // Divider
      dividerTheme: const DividerThemeData(
        color: VybeColors.border,
        thickness: 0.5,
      ),
    );
  }
}
