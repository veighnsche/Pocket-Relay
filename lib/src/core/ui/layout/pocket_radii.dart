import 'package:flutter/widgets.dart';

abstract final class PocketRadii {
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double hero = 32;
  static const double pill = 999;

  static BorderRadius circular(double radius) {
    return BorderRadius.circular(radius);
  }
}
