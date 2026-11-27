import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Couleurs inspirées d'iOS : fonds système, libellés gris, teinte émeraude Adjamé-Smart
class AppColors {
  static const background = Color(0xFFF2F2F7); // fond groupé (Réglages)
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F2F7); // vignettes, champs
  static const fill = Color(0xFFE9E9EB); // boutons gris, pas-à-pas
  static const ink = Color(0xFF000000); // libellé
  static const muted = Color(0xFF8A8A8E); // libellé secondaire
  static const faint = Color(0xFFC5C5C7); // libellé tertiaire, chevrons
  static const line = Color(0xFFE5E5EA); // bordures discrètes
  static const separator = Color(0xFFC6C6C8);
  static const primary = Color(0xFF0B6B4F); // teinte émeraude
  static const primarySoft = Color(0xFFE2EFEA);
  static const accent = Color(0xFFE8962A); // safran
  static const accentSoft = Color(0xFFFCF0DE);
  static const badge = Color(0xFFFF3B30);
  static const success = Color(0xFF248A3D);
  static const warning = Color(0xFFC93400);
  static const danger = Color(0xFFD70015);

  // Anciens noms (écrans vendeur)
  static const primaryDark = primary;
  static const card = surface;
}

/// Typographie système (SF Pro sur iOS), tailles et interlettrages des Human Interface Guidelines
class AppText {
  static const _text = 'CupertinoSystemText';
  static const _display = 'CupertinoSystemDisplay';
  static const display = TextStyle(fontFamily: _display, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 0.37, height: 1.2, color: AppColors.ink);
  static const title1 = TextStyle(fontFamily: _display, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.36, height: 1.2, color: AppColors.ink);
  static const headline = TextStyle(fontFamily: _display, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.35, height: 1.25, color: AppColors.ink);
  static const section = headline;
  static const title = TextStyle(fontFamily: _text, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.43, height: 1.3, color: AppColors.ink);
  static const body = TextStyle(fontFamily: _text, fontSize: 17, letterSpacing: -0.43, height: 1.35, color: AppColors.ink);
  static const bodyMuted = TextStyle(fontFamily: _text, fontSize: 15, letterSpacing: -0.24, height: 1.35, color: AppColors.muted);
  static const label = TextStyle(fontFamily: _text, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.24, color: AppColors.ink);
  static const subhead = TextStyle(fontFamily: _text, fontSize: 15, letterSpacing: -0.24, height: 1.3, color: AppColors.ink);
  static const caption = TextStyle(fontFamily: _text, fontSize: 13, letterSpacing: -0.08, height: 1.3, color: AppColors.muted);
  static const overline = TextStyle(fontFamily: _text, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.08, color: AppColors.muted);
  static const price = TextStyle(fontFamily: _text, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.43, color: AppColors.ink, fontFeatures: [FontFeature.tabularFigures()]);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary, surface: AppColors.surface, onSurface: AppColors.ink);
  final field = BorderRadius.circular(12);
  const cupertino = CupertinoThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    barBackgroundColor: Color(0xCCF9F9F9),
    textTheme: CupertinoTextThemeData(primaryColor: AppColors.primary),
  );
  return ThemeData(
    useMaterial3: true,
    // Comportements iOS partout : transitions avec retour par glissement, rebond, sélection de texte
    platform: TargetPlatform.iOS,
    fontFamily: 'CupertinoSystemText',
    colorScheme: scheme,
    cupertinoOverrideTheme: cupertino,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: const Color(0x0F000000),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppText.title,
      iconTheme: IconThemeData(color: AppColors.primary),
    ),
    textTheme: const TextTheme(bodyMedium: AppText.body, bodyLarge: AppText.body, titleMedium: AppText.title, bodySmall: AppText.caption),
    listTileTheme: const ListTileThemeData(titleTextStyle: AppText.body, subtitleTextStyle: AppText.caption, iconColor: AppColors.primary, tileColor: Colors.transparent),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.fill,
        disabledForegroundColor: AppColors.faint,
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppText.title,
      ),
    ),
    // Bouton secondaire « teinté » façon iOS
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.primarySoft,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppText.title,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: AppText.body)),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.primary)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: AppText.body.copyWith(color: AppColors.faint),
      border: OutlineInputBorder(borderRadius: field, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: field, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: field, borderSide: BorderSide.none),
      disabledBorder: OutlineInputBorder(borderRadius: field, borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(color: AppColors.surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      selectedColor: AppColors.primary,
      labelStyle: AppText.subhead,
      secondaryLabelStyle: AppText.subhead.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.separator, thickness: 0.5, space: 0.5),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.muted, strokeWidth: 2),
    switchTheme: const SwitchThemeData(),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.faint,
      dragHandleSize: Size(36, 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF21C1C1E),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentTextStyle: AppText.subhead.copyWith(color: Colors.white),
    ),
  );
}
