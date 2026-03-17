import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

CupertinoThemeData buildPocketCupertinoTheme(ThemeData materialTheme) {
  return CupertinoThemeData(brightness: materialTheme.brightness);
}
