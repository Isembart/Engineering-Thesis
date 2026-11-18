import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Campus-signage palette. Every screen takes its colors from here.
abstract final class Palette {
  static const bg = Color(0xFFEFF4FF);
  static const panel = Color(0xFFFFFFFF);
  static const ink = Color(0xFF14213D);
  static const muted = Color(0xFF5A6785);
  static const line = Color(0xFFD6E0F5);
  /// Buttons, selection, the measured line in the chart.
  static const accent = Color(0xFF2563EB);
  // Status colors: green quieter, blue as usual, red busier.
  static const quieter = Color(0xFF22C55E);
  static const usual = Color(0xFF2563EB);
  static const busier = Color(0xFFDC2626);
  static const offline = Color(0xFFCBD3E1);
  /// No history yet; also the typical-range band in the chart.
  static const learning = Color(0xFFDCE7FF);
  /// Heatmap ramp, few people to many.
  static const heatLow = Color(0xFFDBEAFE);
  static const heatMid = Color(0xFF3B82F6);
  static const heatHigh = Color(0xFF1E3A8A);
}

const radius = BorderRadius.all(Radius.circular(6));
const tabular = [FontFeature.tabularFigures()];

TextStyle archivo(double size, {FontWeight weight = FontWeight.w400, Color color = Palette.ink, double? spacing}) =>
    GoogleFonts.archivo(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      fontFeatures: tabular,
    );

/// Place names and screen headings.
TextStyle heading(double size) => archivo(size, weight: FontWeight.w800, spacing: -0.4);

ThemeData buildTheme() {
  final base = ThemeData.light();
  const scheme = ColorScheme.light(
    primary: Palette.accent,
    onPrimary: Colors.white,
    secondary: Palette.accent,
    onSecondary: Colors.white,
    surface: Palette.panel,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.muted,
    outline: Palette.line,
    surfaceTint: Colors.transparent,
  );
  const buttonShape = RoundedRectangleBorder(borderRadius: radius);
  const buttonPadding = EdgeInsets.symmetric(vertical: 16, horizontal: 20);
  final buttonText = archivo(15, weight: FontWeight.w600);
  final border = OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Palette.line));

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    textTheme: GoogleFonts.archivoTextTheme(base.textTheme).apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: heading(18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.panel,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: Palette.accent, width: 1.5)),
      labelStyle: archivo(15, color: Palette.muted),
      helperStyle: archivo(12, color: Palette.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Palette.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Palette.line,
        elevation: 0,
        shape: buttonShape,
        padding: buttonPadding,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        side: const BorderSide(color: Palette.line),
        shape: buttonShape,
        padding: buttonPadding,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Palette.ink, shape: buttonShape, textStyle: buttonText),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Palette.panel,
        foregroundColor: Palette.ink,
        selectedBackgroundColor: Palette.accent,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: Palette.line),
        shape: buttonShape,
        textStyle: archivo(13, weight: FontWeight.w600),
        visualDensity: VisualDensity.compact,
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Palette.panel, shape: buttonShape),
    popupMenuTheme: const PopupMenuThemeData(color: Palette.panel, shape: buttonShape),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.ink,
      contentTextStyle: archivo(14, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: buttonShape,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(color: Palette.ink, borderRadius: radius),
      textStyle: archivo(12, color: Colors.white),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.accent, linearTrackColor: Palette.line),
  );
}

/// White panel with a hairline border; the base of cards, chart and heatmap.
BoxDecoration panelDecoration() => BoxDecoration(
      color: Palette.panel,
      borderRadius: radius,
      border: Border.all(color: Palette.line),
    );

/// Grey shape standing in for content that is still loading.
class Skeleton extends StatelessWidget {
  final double height;
  final double? width;

  const Skeleton({super.key, required this.height, this.width});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: const BoxDecoration(color: Palette.heatLow, borderRadius: radius),
      );
}
