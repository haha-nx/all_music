import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/constants.dart';

/// 封面图组件 — 支持网络图 + 占位 + 旋转动画
class AlbumArt extends StatelessWidget {
  final String? coverUrl;
  final double size;
  final bool isPlaying;
  final double borderRadius;

  /// 播放时的光晕颜色（默认主题色；可传专辑主题色）
  final Color glowColor;

  const AlbumArt({
    super.key,
    this.coverUrl,
    this.size = 48,
    this.isPlaying = false,
    this.borderRadius = 8,
    this.glowColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: coverUrl != null
            ? CachedNetworkImage(
                imageUrl: coverUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => _buildPlaceholder(),
                errorWidget: (_, _, _) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceDark,
      child: Icon(
        Icons.music_note,
        size: size * 0.5,
        color: AppColors.textTertiary,
      ),
    );
  }
}
