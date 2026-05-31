import 'package:flutter/material.dart';

class AppTheme {
  static const success = Color(0xFF16845B);
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFB3261E);
  static const info = Color(0xFF2563A9);
  static const heart = Color(0xFFC24158);
  static const oxygen = Color(0xFF007C89);

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF007C89),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF007C89),
          secondary: const Color(0xFF2A9D8F),
          tertiary: const Color(0xFF3A6EA5),
          surface: const Color(0xFFFFFFFF),
          surfaceContainerHighest: const Color(0xFFEAF5F3),
          error: danger,
        );
    return _theme(scheme, const Color(0xFFF4FAF8));
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DD0C8),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF66D7D1),
          secondary: const Color(0xFF83D9C4),
          tertiary: const Color(0xFF9CCBFF),
          error: const Color(0xFFFFB4AB),
        );
    return _theme(scheme, const Color(0xFF071312));
  }

  static ThemeData _theme(ColorScheme scheme, Color scaffoldBackground) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        shadowColor: scheme.shadow.withValues(alpha: 0.10),
        surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.04),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 2,
        height: 72,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            letterSpacing: 0,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
      ),
    );
  }
}
