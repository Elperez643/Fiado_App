import 'package:flutter/material.dart';

class AppMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve ease = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}
