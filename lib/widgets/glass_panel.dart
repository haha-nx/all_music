import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/constants.dart';

/// 液态玻璃面板组件 — 基于 Flutter 内置 BackdropFilter
///
/// 替代 liquid_glass_widgets，避免第三方库的渲染不稳定问题
/// (首帧模糊、路由切换 native crash)。
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final Color? tintColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool showBorder;
  final Color? borderColor;

  /// 正圆形状（忽略 [borderRadius]，半径=尺寸一半，任何屏幕都保持正圆）
  final bool circle;

  /// 胶囊形状（忽略 [borderRadius]，圆角=高度一半）
  final bool stadium;

  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 8,
    this.borderRadius = 16,
    this.tintColor,
    this.width,
    this.height,
    this.padding,
    this.showBorder = false,
    this.borderColor,
    this.circle = false,
    this.stadium = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = tintColor ?? AppColors.surfaceLight;
    final Widget blurred = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    Widget panel;
    if (circle) {
      panel = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: showBorder
                  ? Border.all(
                      color: borderColor ??
                          AppColors.textTertiary.withValues(alpha: 0.15),
                      width: 0.5,
                    )
                  : null,
            ),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      );
    } else if (stadium) {
      panel = ClipPath(
        clipper: const ShapeBorderClipper(shape: StadiumBorder()),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: width,
            height: height,
            decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      );
    } else {
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: blurred,
      );
    }

    return panel;
  }
}
