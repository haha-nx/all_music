import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 专辑封面主题色（提取自封面主色）
///
/// - [dominant]：主色，用于激活/强调态控件（播放按钮、进度条、选中项等）
/// - [onDominant]：与 [dominant] 高对比的前景色（黑或白），
///   用于未激活/普通态控件，保证可读性
class CoverTheme {
  const CoverTheme({required this.dominant, required this.onDominant});

  final Color dominant;

  /// 与 [dominant] 对比的前景色：亮色主题 → 黑，暗色主题 → 白
  final Color onDominant;

  /// 主色是否偏暗
  bool get isDark => dominant.computeLuminance() < 0.5;
}

/// 提取后的主题色缓存（按封面 URL），避免切歌来回时重复解码
const int _maxCache = 8;
final Map<String, CoverTheme> _cache = {};

/// 提取专辑封面的主题色；封面缺失或提取失败返回 null
Future<CoverTheme?> extractCoverTheme(String? coverUrl) async {
  if (coverUrl == null || coverUrl.isEmpty) return null;
  final cached = _cache[coverUrl];
  if (cached != null) return cached;

  final theme = await _extract(coverUrl);
  if (theme != null) {
    if (_cache.length >= _maxCache) {
      _cache.remove(_cache.keys.first);
    }
    _cache[coverUrl] = theme;
  }
  return theme;
}

Future<CoverTheme?> _extract(String coverUrl) async {
  ui.Image? image;
  ImageStream? stream;
  ImageStreamListener? listener;
  try {
    final completer = Completer<ui.Image>();
    final provider = CachedNetworkImageProvider(coverUrl);
    stream = provider.resolve(const ImageConfiguration());
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (exception, stackTrace) {
        if (!completer.isCompleted) completer.completeError(exception);
      },
    );
    stream.addListener(listener);
    image = await completer.future.timeout(const Duration(seconds: 10));

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;
    final dominant = dominantColorFromPixels(byteData, image.width, image.height);
    return CoverTheme(
      dominant: dominant,
      onDominant: dominant.computeLuminance() > 0.5
          ? Colors.black
          : Colors.white,
    );
  } catch (_) {
    return null; // 网络失败/解码失败时静默回退
  } finally {
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    image?.dispose();
  }
}

/// 从 RGBA 像素中提取主色：
/// 降采样后按色相分桶，取「高饱和 + 中等亮度」权重最大的色相桶平均色；
/// 图片接近黑白时回退为平均亮度灰。
///
/// 公开以便单元测试验证（[ByteData] 布局为 rawRgba：每像素 R,G,B,A）。
@visibleForTesting
Color dominantColorFromPixels(ByteData data, int width, int height) {
  const bucketCount = 24; // 每 15° 一个色相桶
  final buckets = List.generate(
      bucketCount, (_) => <double>[0, 0, 0, 0]); // [权重, Σh, Σs, Σl]

  var lSum = 0.0;
  var count = 0;
  var bestWeight = 0.0;
  var best = -1;

  final stride = width * 4;
  for (var y = 0; y < height; y += 2) {
    for (var x = 0; x < width; x += 2) {
      final offset = y * stride + x * 4;
      if (data.getUint8(offset + 3) < 200) continue; // 跳过透明像素
      final r = data.getUint8(offset) / 255.0;
      final g = data.getUint8(offset + 1) / 255.0;
      final b = data.getUint8(offset + 2) / 255.0;
      final (h, s, l) = _rgbToHsl(r, g, b);
      lSum += l;
      count++;

      // 跳过接近黑白/低饱和的像素
      if (l < 0.08 || l > 0.94 || s < 0.12) continue;
      // 权重：偏好高饱和且不过亮/过暗的颜色
      final w = s * (1.0 - (l - 0.5).abs() * 1.4);
      if (w <= 0.001) continue;

      final bucket = (h * bucketCount / 360).floor() % bucketCount;
      final bkt = buckets[bucket];
      bkt[0] += w;
      bkt[1] += h * w;
      bkt[2] += s * w;
      bkt[3] += l * w;
      if (bkt[0] > bestWeight) {
        bestWeight = bkt[0];
        best = bucket;
      }
    }
  }

  if (best < 0 || bestWeight <= 0) {
    // 基本是黑白图片 → 平均亮度灰
    final avgL = count > 0 ? lSum / count : 0.5;
    final v = (avgL * 255).round();
    return Color.fromARGB(255, v, v, v);
  }
  final bkt = buckets[best];
  return _hslToRgb(bkt[1] / bkt[0], bkt[2] / bkt[0], bkt[3] / bkt[0]);
}

/// RGB(0~1) → HSL(deg, 0~1, 0~1)
(double, double, double) _rgbToHsl(double r, double g, double b) {
  final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final l = (max + min) / 2;
  if (max == min) return (0, 0, l);

  final d = max - min;
  final s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  double h;
  if (max == r) {
    h = (g - b) / d + (g < b ? 6 : 0);
  } else if (max == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return (h * 60, s, l);
}

/// HSL → RGB(0~1)
Color _hslToRgb(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final hp = h / 60;
  final x = c * (1 - (hp % 2 - 1).abs());
  double r = 0, g = 0, b = 0;
  if (hp < 1) {
    r = c;
    g = x;
  } else if (hp < 2) {
    r = x;
    g = c;
  } else if (hp < 3) {
    g = c;
    b = x;
  } else if (hp < 4) {
    g = x;
    b = c;
  } else if (hp < 5) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  final m = l - c / 2;
  return Color.fromARGB(
    255,
    ((r + m) * 255).round().clamp(0, 255).toInt(),
    ((g + m) * 255).round().clamp(0, 255).toInt(),
    ((b + m) * 255).round().clamp(0, 255).toInt(),
  );
}
