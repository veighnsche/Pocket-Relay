import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';

@immutable
class PocketPalette extends ThemeExtension<PocketPalette> {
  const PocketPalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.sheetBackground,
    required this.surface,
    required this.surfaceBorder,
    required this.subtleSurface,
    required this.inputFill,
    required this.dragHandle,
    required this.shadowColor,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color sheetBackground;
  final Color surface;
  final Color surfaceBorder;
  final Color subtleSurface;
  final Color inputFill;
  final Color dragHandle;
  final Color shadowColor;

  static const PocketPalette light = PocketPalette(
    backgroundTop: Color(0xFFF4EFE5),
    backgroundBottom: Color(0xFFECE4D4),
    sheetBackground: Color(0xFFF4EFE5),
    surface: Color(0xFFFFFCF6),
    surfaceBorder: Color(0xFFD7CDB8),
    subtleSurface: Color(0xFFEEE7D8),
    inputFill: Color(0xFFFFFFFF),
    dragHandle: Color(0xFFD6CCB7),
    shadowColor: Color(0x14000000),
  );

  static const PocketPalette dark = PocketPalette(
    backgroundTop: Color(0xFF0E1415),
    backgroundBottom: Color(0xFF071011),
    sheetBackground: Color(0xFF111A1B),
    surface: Color(0xFF162123),
    surfaceBorder: Color(0xFF2D4245),
    subtleSurface: Color(0xFF203033),
    inputFill: Color(0xFF1C2A2C),
    dragHandle: Color(0xFF466164),
    shadowColor: Color(0x66000000),
  );

  @override
  PocketPalette copyWith({
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? sheetBackground,
    Color? surface,
    Color? surfaceBorder,
    Color? subtleSurface,
    Color? inputFill,
    Color? dragHandle,
    Color? shadowColor,
  }) {
    return PocketPalette(
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      sheetBackground: sheetBackground ?? this.sheetBackground,
      surface: surface ?? this.surface,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      subtleSurface: subtleSurface ?? this.subtleSurface,
      inputFill: inputFill ?? this.inputFill,
      dragHandle: dragHandle ?? this.dragHandle,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  ThemeExtension<PocketPalette> lerp(
    covariant ThemeExtension<PocketPalette>? other,
    double t,
  ) {
    if (other is! PocketPalette) {
      return this;
    }

    return PocketPalette(
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(
        backgroundBottom,
        other.backgroundBottom,
        t,
      )!,
      sheetBackground: Color.lerp(sheetBackground, other.sheetBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      dragHandle: Color.lerp(dragHandle, other.dragHandle, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}

ThemeData buildPocketTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? PocketPalette.dark
      : PocketPalette.light;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F766E),
    brightness: brightness,
  );
  final scheme = baseScheme.copyWith(
    surface: palette.surface,
    surfaceContainerHighest: palette.subtleSurface,
    outlineVariant: palette.surfaceBorder,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.backgroundTop,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.backgroundTop,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.inputFill,
      border: OutlineInputBorder(
        borderRadius: PocketRadii.circular(PocketRadii.lg),
        borderSide: BorderSide(color: palette.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: PocketRadii.circular(PocketRadii.lg),
        borderSide: BorderSide(color: palette.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: PocketRadii.circular(PocketRadii.lg),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    extensions: <ThemeExtension<dynamic>>[palette],
  );
}

extension PocketPaletteBuildContext on BuildContext {
  PocketPalette get pocketPalette {
    return Theme.of(this).extension<PocketPalette>()!;
  }
}
