import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.warmBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandGold,
        brightness: Brightness.dark,
        primary: AppColors.brandGold,
        secondary: AppColors.brandGold,
        surface: AppColors.cardBackground,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.cocoaText),
        bodyMedium: TextStyle(color: AppColors.cocoaText),
        bodySmall: TextStyle(color: AppColors.mutedOliveText),
        titleLarge: TextStyle(color: AppColors.cocoaText),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.softBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBackground,
        labelStyle: const TextStyle(color: AppColors.mutedOliveText),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandGold),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandGold,
          foregroundColor: AppColors.warmBackground,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cocoaText,
          side: const BorderSide(color: AppColors.softBorder),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardBackground,
        selectedItemColor: AppColors.brandGold,
        unselectedItemColor: AppColors.mutedOliveText,
      ),
    );
  }
}
