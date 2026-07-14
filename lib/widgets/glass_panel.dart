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
  });

  @override
  Widget build(BuildContext context) {
    Widget panel = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: tintColor ?? AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(borderRadius),
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

    return panel;
  }
}
