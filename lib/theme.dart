import 'package:flutter/material.dart';

/// Palette Adjamé-Smart : ivoire, encre, émeraude profond, touche safran (thème par défaut, à affiner avec l'identité définitive)
class AppColors {
  static const background = Color(0xFFF6F4EF); // ivoire
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFEFECE5); // fonds de vignettes, champs
  static const ink = Color(0xFF16130F);
  static const muted = Color(0xFF77716A);
  static const faint = Color(0xFFA9A39B);
  static const line = Color(0xFFE6E1D8);
  static const primary = Color(0xFF0E5A43); // émeraude
  static const primarySoft = Color(0xFFE3EFE9);
  static const accent = Color(0xFFD9962F); // safran
  static const accentSoft = Color(0xFFF7ECD9);
  static const success = Color(0xFF1F8A4C);
  static const warning = Color(0xFFB4561B);
  static const danger = Color(0xFFB42318);

  // Anciens noms (écrans vendeur)
  static const primaryDark = primary;
  static const card = surface;
}

/// Typographie : DM Serif pour les titres éditoriaux, Inter pour le reste
class AppText {
  static const _inter = 'Inter';
  static const display = TextStyle(fontFamily: 'DMSerif', fontSize: 34, height: 1.08, letterSpacing: -0.4, color: AppColors.ink);
  static const headline = TextStyle(fontFamily: 'DMSerif', fontSize: 26, height: 1.12, letterSpacing: -0.2, color: AppColors.ink);
  static const section = TextStyle(fontFamily: 'DMSerif', fontSize: 22, height: 1.15, color: AppColors.ink);
  static const title = TextStyle(fontFamily: _inter, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.ink);
  static const body = TextStyle(fontFamily: _inter, fontSize: 15, height: 1.45, color: AppColors.ink);
  static const bodyMuted = TextStyle(fontFamily: _inter, fontSize: 15, height: 1.45, color: AppColors.muted);
  static const label = TextStyle(fontFamily: _inter, fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const caption = TextStyle(fontFamily: _inter, fontSize: 12.5, color: AppColors.muted);
  static const overline = TextStyle(fontFamily: _inter, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: AppColors.muted);
  static const price = TextStyle(fontFamily: _inter, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.ink, fontFeatures: [FontFeature.tabularFigures()]);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary, surface: AppColors.surface, onSurface: AppColors.ink);
  final radius = BorderRadius.circular(16);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppText.title,
    ),
    textTheme: const TextTheme(bodyMedium: AppText.body, bodyLarge: AppText.body, titleMedium: AppText.title),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: AppColors.line, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.faint),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.ink, width: 1.4)),
      disabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.line)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(color: AppColors.surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.line))),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.ink,
      labelStyle: AppText.label,
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.line),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.background, surfaceTintColor: Colors.transparent, showDragHandle: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), contentTextStyle: const TextStyle(fontFamily: 'Inter', color: Colors.white)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.ink),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      ),
    ),
  );
}
