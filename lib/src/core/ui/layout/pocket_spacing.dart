import 'package:flutter/widgets.dart';

abstract final class PocketSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 20;
  static const double xxxl = 24;
  static const double huge = 28;
  static const double giant = 32;

  static const EdgeInsets panelPadding = EdgeInsets.all(xl);
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(lg, md, lg, lg);
}
