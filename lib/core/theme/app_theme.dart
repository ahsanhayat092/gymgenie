import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Central design system for GymGenie.
///
/// A premium dark-only theme with a warm amber/gold accent, deep charcoal
/// surfaces, and athletic typography. All component themes are tuned for
/// fitness-app density: large touch targets, high-contrast figures, and
/// consistent rounded geometry.
class AppTheme {
  AppTheme._();

  // ── Core palette ─────────────────────────────────────────────────────────
  static const Color _background = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF141414);
  static const Color _surfaceElevated = Color(0xFF1C1C1E);
  static const Color _surfaceContainer = Color(0xFF232326);
  static const Color _outline = Color(0xFF2C2C2E);
  static const Color _outlineVariant = Color(0xFF3A3A3C);

  static const Color _primary = Color(0xFFFFB020);
  static const Color _primaryContainer = Color(0xFF332A15);
  static const Color _onPrimaryContainer = Color(0xFFFFE6B3);
  static const Color _secondary = Color(0xFF34D399);
  static const Color _secondaryContainer = Color(0xFF0F2922);
  static const Color _tertiary = Color(0xFFA78BFA);
  static const Color _tertiaryContainer = Color(0xFF2E2654);
  static const Color _error = Color(0xFFFF453A);
  static const Color _errorContainer = Color(0xFF3D1513);
  static const Color _onErrorContainer = Color(0xFFFFDAD6);

  static const Color _onSurface = Color(0xFFE5E5EA);
  static const Color _onSurfaceVariant = Color(0xFF8E8E93);
  static const Color _onSurfaceDim = Color(0xFF636366);

  // ── Spacing scale ────────────────────────────────────────────────────────
  static const double spaceUnit = 4.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusMax = 32.0;

  // ── Typography helpers ───────────────────────────────────────────────────
  static TextTheme _buildTextTheme(TextTheme base) {
    const textColor = _onSurface;
    const variantColor = _onSurfaceVariant;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      displaySmall: base.displaySmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: variantColor,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        color: variantColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: variantColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  // ── Theme ────────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
      primary: _primary,
      primaryContainer: _primaryContainer,
      onPrimaryContainer: _onPrimaryContainer,
      secondary: _secondary,
      secondaryContainer: _secondaryContainer,
      tertiary: _tertiary,
      tertiaryContainer: _tertiaryContainer,
      surface: _surface,
      surfaceContainerHighest: _surfaceContainer,
      error: _error,
      errorContainer: _errorContainer,
      onErrorContainer: _onErrorContainer,
      onSurface: _onSurface,
      onSurfaceVariant: _onSurfaceVariant,
      outline: _outline,
      outlineVariant: _outlineVariant,
    );

    final textTheme = _buildTextTheme(Typography.material2021().white);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        foregroundColor: _onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: _surfaceElevated,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: _outline, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceElevated,
        hintStyle: textTheme.bodyLarge?.copyWith(color: _onSurfaceDim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: _outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: _outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: _error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _surfaceElevated,
          foregroundColor: _onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: _outlineVariant, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black54,
        elevation: 8,
        indicatorColor: _primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? _primary : _onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _primary : _onSurfaceVariant,
            size: selected ? 26 : 24,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: _outline,
        thickness: 1,
        indent: 16,
        endIndent: 16,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceElevated,
        selectedColor: _primaryContainer,
        disabledColor: _surfaceContainer,
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: _onPrimaryContainer,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMax),
          side: const BorderSide(color: _outline),
        ),
        side: const BorderSide(color: _outline),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return _onSurfaceDim;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primaryContainer;
          return _surfaceContainer;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _primary,
        inactiveTrackColor: _surfaceContainer,
        thumbColor: _primary,
        overlayColor: _primary.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: _surfaceContainer,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Shared decoration / layout helpers used across the app.
extension AppDecorations on Never {
  static BoxDecoration cardGradient(BuildContext context, List<Color> colors) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
      ),
    );
  }

  static BoxShadow cardShadow(BuildContext context) {
    return BoxShadow(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    );
  }

  static BoxShadow floatingShadow(BuildContext context) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 30,
      offset: const Offset(0, 10),
    );
  }
}
