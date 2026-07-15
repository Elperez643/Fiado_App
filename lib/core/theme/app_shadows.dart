import 'package:flutter/material.dart';

class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x12000000), blurRadius: 20, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x1A17322C), blurRadius: 28, offset: Offset(0, 16)),
  ];

  static const List<BoxShadow> pressed = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 6)),
  ];
}
