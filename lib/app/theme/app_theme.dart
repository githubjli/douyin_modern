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
        brightness: Brightness.light,
        primary: AppColors.brandGold,
        secondary: AppColors.deepGold,
        surface: AppColors.cardBackground,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.softBorder),
        ),
      ),
    );
  }
}
