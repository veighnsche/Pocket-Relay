import 'package:flutter/material.dart';

abstract final class PocketFontFamilies {
  static const String monospace = 'JetBrainsMono';
}

abstract final class PocketTypography {
  static TextStyle monospaceStyle({
    TextStyle? base,
    Color? color,
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
    double? letterSpacing,
    Color? backgroundColor,
  }) {
    final source = base ?? const TextStyle();
    return source.copyWith(
      color: color ?? source.color,
      fontSize: fontSize ?? source.fontSize,
      height: height ?? source.height,
      fontWeight: fontWeight ?? source.fontWeight,
      letterSpacing: letterSpacing ?? source.letterSpacing,
      backgroundColor: backgroundColor ?? source.backgroundColor,
      fontFamily: PocketFontFamilies.monospace,
      fontFamilyFallback: const <String>[
        'SF Mono',
        'Menlo',
        'Monaco',
        'Consolas',
        'Roboto Mono',
        'Noto Sans Mono',
        'Liberation Mono',
        'Courier New',
        'monospace',
      ],
    );
  }

  static TextStyle monospace(
    BuildContext context, {
    TextStyle? base,
    Color? color,
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
    double? letterSpacing,
    Color? backgroundColor,
  }) {
    return monospaceStyle(
      base: base ?? Theme.of(context).textTheme.bodyMedium,
      color: color,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      backgroundColor: backgroundColor,
    );
  }
}
