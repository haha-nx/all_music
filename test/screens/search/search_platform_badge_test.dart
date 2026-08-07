import 'package:all_music/music_source/builtin/builtin_platforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kSourceKeyNames covers all builtin platforms', () {
    expect(kSourceKeyNames['wy'], '网易云');
    expect(kSourceKeyNames['tx'], 'QQ音乐');
    expect(kSourceKeyNames['kg'], '酷狗');
    expect(kSourceKeyNames['kw'], '酷我');
    expect(kSourceKeyNames['mg'], '咪咕');
    // 所有内置平台都有显示名
    for (final p in kBuiltinPlatforms) {
      expect(kSourceKeyNames.containsKey(p.sourceKey), isTrue,
          reason: '${p.sourceKey} 缺少显示名');
    }
  });
}
