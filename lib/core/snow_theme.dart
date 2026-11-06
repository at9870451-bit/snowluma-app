import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Shared visual tokens; page-specific behaviour stays in each feature page.
abstract final class SnowStyle {
  static const background = Color(0xFFF4F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF18191D);
  static const muted = Color(0xFF6D707A);
  static const accent = Color(0xFF525DB2);
  static const softAccent = Color(0xFFEBEDF8);
  static const softSurface = Color(0xFFF1F2F5);
  static const radius = 22.0;
  static const insetRadius = 14.0;
  static const tabular = <FontFeature>[FontFeature.tabularFigures()];

  static const shadows = <BoxShadow>[
    BoxShadow(color: Color(0x080E1726), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0C0E1726), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static BoxDecoration card({Color color = surface, double radius = SnowStyle.radius}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadows,
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: surface,
    ).copyWith(primary: accent, onSurface: ink);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(insetRadius),
      borderSide: BorderSide.none,
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softSurface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(insetRadius),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(insetRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: Color(0x66525DB2),
        selectionHandleColor: accent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
      }),
    );
  }
}
