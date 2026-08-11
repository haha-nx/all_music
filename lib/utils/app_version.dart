import 'package:flutter/services.dart' show rootBundle;

/// 从 pubspec.yaml 读取应用版本号
///
/// pubspec.yaml 已被声明为 asset，运行时读取文本并解析 `version:` 字段，
/// 避免版本号硬编码在设置页中。
class AppVersion {
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    try {
      final yaml = await rootBundle.loadString('pubspec.yaml');
      final match =
          RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(yaml);
      _cached = match?.group(1) ?? '1.0.0';
    } catch (_) {
      _cached = '1.0.0'; // 资源缺失等异常时回退
    }
    return _cached!;
  }
}
