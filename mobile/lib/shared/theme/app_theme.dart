import 'package:flutter/material.dart';

class AppColors {
  // Primary palette — deep navy + electric blue accent
  static const background = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const surfaceElevated = Color(0xFF1C2333);
  static const border = Color(0xFF30363D);

  static const accent = Color(0xFF58A6FF);
  static const accentDim = Color(0xFF1F4E8C);
  static const accentGlow = Color(0x3358A6FF);

  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);

  // Status colors
  static const success = Color(0xFF3FB950);
  static const successDim = Color(0xFF1A3A22);
  static const warning = Color(0xFFD29922);
  static const warningDim = Color(0xFF3A2D0A);
  static const error = Color(0xFFF85149);
  static const errorDim = Color(0xFF3A1212);
  static const info = Color(0xFF58A6FF);
  static const infoDim = Color(0xFF1F4E8C);

  // Interceptor tag colors
  static const tagNetwork = Color(0xFF58A6FF);
  static const tagAuth = Color(0xFFA371F7);
  static const tagCache = Color(0xFF3FB950);
  static const tagError = Color(0xFFF85149);
  static const tagSecurity = Color(0xFFD29922);
  static const tagPerf = Color(0xFFFF7B72);
  static const tagState = Color(0xFF79C0FF);
  static const tagLog = Color(0xFF8B949E);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        fontFamily: 'monospace',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: AppColors.textSecondary),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.accent),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      );
}
