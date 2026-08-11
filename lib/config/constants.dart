import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
/// 全局尺寸常量 — 移动端按 390x844 基准缩放（长宽 .w），圆角不缩放
class AppSizes {
  static double get barHeight => 64.w;
  static double get paddingH => 20.w;
  static double get paddingV => 16.w;
  static double get spacing => 8.w;
  static double get playPillHeight => 56.w;
  static double get albumArtSize => 48.w;
  static double get miniAlbumArtSize => 36.w;
  static const double borderRadius = 12.0; // 圆角不缩放
  static const double cardBorderRadius = 20.0; // 圆角不缩放

  // 导航栏
  static double get navBarHeight => 60.w;
  static const double navBarRadius = 28.0; // 圆角不缩放
  static double get navBarBottom => 16.w;
}
