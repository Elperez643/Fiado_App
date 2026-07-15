import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppGradients {
  static const LinearGradient executive = LinearGradient(
    colors: [AppColors.primaryDark, AppColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient trust = LinearGradient(
    colors: [AppColors.petroleum, AppColors.blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient alert = LinearGradient(
    colors: [Color(0xFF8C4B12), AppColors.warning],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient risk = LinearGradient(
    colors: [Color(0xFF7A1B14), AppColors.danger],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGlow = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF1F8F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
