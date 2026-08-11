import 'package:flutter/material.dart';

/// 全局颜色常量
class AppColors {
  // 主题色
  static const Color primary = Color(0xFFFA2D48);
  static const Color accent = Color(0xFFFA2D48);
  static const Color accentPurple = Color(0xFFAF52DE);
  static const Color accentBlue = Color(0xFF5AC8FA);
  static const Color accentGreen = Color(0xFF34C759);

  // 背景色
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color surfaceLight = Color(0x1AFFFFFF);

  // 文字色
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);

  // 状态色
  static const Color error = Color(0xFFFF453A);
  static const Color success = Color(0xFF30D158);
}

/// 全局尺寸常量
class AppSizes {
  static const double barHeight = 64.0;
  static const double paddingH = 20.0;
  static const double paddingV = 16.0;
  static const double spacing = 8.0;
  static const double playPillHeight = 56.0;
  static const double albumArtSize = 48.0;
  static const double miniAlbumArtSize = 36.0;
  static const double borderRadius = 12.0;
  static const double cardBorderRadius = 20.0;

  // 导航栏
  static const double navBarHeight = 60.0;
  static const double navBarRadius = 28.0;
  static const double navBarBottom = 16.0;
}
