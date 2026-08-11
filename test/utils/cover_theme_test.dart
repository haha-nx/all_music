import 'dart:typed_data';

import 'package:all_music/utils/cover_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一张纯色图片的 rawRgba 像素数据
ByteData _solidImage(Color c, int w, int h) {
  final data = ByteData(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      data.setUint8(o, (c.r * 255).round());
      data.setUint8(o + 1, (c.g * 255).round());
      data.setUint8(o + 2, (c.b * 255).round());
      data.setUint8(o + 3, 255);
    }
  }
  return data;
}

Color _onDominant(Color dominant) =>
    dominant.computeLuminance() > 0.5 ? Colors.black : Colors.white;

void main() {
  test('纯红色封面 → 主题色为红，对比色为白', () {
    final dominant = dominantColorFromPixels(
        _solidImage(const Color(0xFFFF0000), 32, 32), 32, 32);
    expect(dominant.r, greaterThan(0.9));
    expect(dominant.g, lessThan(0.1));
    expect(dominant.b, lessThan(0.1));
    expect(_onDominant(dominant), Colors.white);
  });

  test('纯蓝色封面 → 主题色为蓝（色相桶投票）', () {
    final dominant = dominantColorFromPixels(
        _solidImage(const Color(0xFF0000FF), 32, 32), 32, 32);
    expect(dominant.b, greaterThan(0.9));
    expect(dominant.r, lessThan(0.1));
    expect(dominant.g, lessThan(0.1));
  });

  test('纯白色封面 → 对比色为黑（保证可读性）', () {
    final dominant = dominantColorFromPixels(
        _solidImage(const Color(0xFFFFFFFF), 16, 16), 16, 16);
    expect(_onDominant(dominant), Colors.black);
  });

  test('纯黑色封面 → 对比色为白', () {
    final dominant = dominantColorFromPixels(
        _solidImage(const Color(0xFF000000), 16, 16), 16, 16);
    expect(dominant.computeLuminance(), lessThan(0.5));
    expect(_onDominant(dominant), Colors.white);
  });

  test('透明像素被忽略（全透明 → 回退灰色）', () {
    final data = ByteData(16 * 16 * 4); // alpha 全为 0
    final dominant = dominantColorFromPixels(data, 16, 16);
    // 回退为中性灰，不会抛异常
    expect(dominant.a, greaterThan(0.9));
  });
}
