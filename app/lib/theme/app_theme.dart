import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colour tokens for the app.
///
/// The greys come from the WhatsApp/Facebook dark family — deep blue-black
/// rather than pure black, which keeps long chart sessions easy on the eyes and
/// lets the green/red P&L colours stay the brightest thing on screen.
class AppColors {
  const AppColors._();

  // Surfaces, from furthest back to closest to the user.
  static const bg = Color(0xFF0B141A);
  static const surface = Color(0xFF111B21);
  static const elevated = Color(0xFF1F2C34);
  static const overlay = Color(0xFF233138);
  static const border = Color(0xFF2A3942);

  // Text.
  static const textPrimary = Color(0xFFE9EDEF);
  static const textSecondary = Color(0xFF8696A0);
  static const textMuted = Color(0xFF667781);

  /// Brand / primary call-to-action.
  static const brand = Color(0xFF00A884);
  static const brandDim = Color(0xFF14624E);

  // Market semantics. Profit is deliberately a brighter green than [brand] so a
  // winning position never reads as "just another button".
  static const profit = Color(0xFF00D68F);
  static const loss = Color(0xFFF6465D);
  static const profitDim = Color(0xFF0E3B31);
  static const lossDim = Color(0xFF45222B);

  /// Discipline score — the metric this app ranks people by. Violet keeps it
  /// visually separate from profit/loss so it never reads as money.
  static const discipline = Color(0xFF7C5CFF);
  static const disciplineDim = Color(0xFF2A2350);

  static const warning = Color(0xFFFFB02E);
  static const warningDim = Color(0xFF4A3617);

  /// Colour for a signed number: green up, red down, grey flat.
  static Color forValue(double v) {
    if (v > 0) return profit;
    if (v < 0) return loss;
    return textSecondary;
  }
}

/// Spacing scale. Everything in the UI is a multiple of 4.
class Gap {
  const Gap._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const h4 = SizedBox(height: 4);
  static const h8 = SizedBox(height: 8);
  static const h12 = SizedBox(height: 12);
  static const h16 = SizedBox(height: 16);
  static const h24 = SizedBox(height: 24);
  static const h32 = SizedBox(height: 32);

  static const w4 = SizedBox(width: 4);
  static const w8 = SizedBox(width: 8);
  static const w12 = SizedBox(width: 12);
  static const w16 = SizedBox(width: 16);
}

class Radii {
  const Radii._();
  static const card = BorderRadius.all(Radius.circular(16));
  static const tile = BorderRadius.all(Radius.circular(12));
  static const pill = BorderRadius.all(Radius.circular(999));
  static const field = BorderRadius.all(Radius.circular(10));
}

/// Numbers in a trading UI must line up vertically, so every price, P&L figure
/// and R-multiple uses tabular figures.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.brand,
    onPrimary: Color(0xFF03211A),
    secondary: AppColors.discipline,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.loss,
    onError: Colors.white,
    outline: AppColors.border,
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    useMaterial3: true,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          headlineSmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleSmall: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textPrimary,
          ),
          bodySmall: const TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: AppColors.textMuted,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: Radii.card),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        disabledBackgroundColor: AppColors.elevated,
        disabledForegroundColor: AppColors.textMuted,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.elevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      border: const OutlineInputBorder(
        borderRadius: Radii.field,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: Radii.field,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: Radii.field,
        borderSide: BorderSide(color: AppColors.brand, width: 1.5),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.brand,
      inactiveTrackColor: AppColors.elevated,
      thumbColor: AppColors.brand,
      trackHeight: 4,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.brandDim,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? AppColors.brand
              : AppColors.textMuted,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.overlay,
      contentTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: Radii.tile),
    ),
  );
}
