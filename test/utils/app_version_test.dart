import 'package:all_music/utils/app_version.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pubspec.yaml 作为 asset 可读取并解析 version', () async {
    final yaml = await rootBundle.loadString('pubspec.yaml');
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(yaml);
    expect(match, isNotNull, reason: 'pubspec.yaml 中应存在 version 字段');
  });

  test('AppVersion.get 返回 pubspec.yaml 中的版本号', () async {
    final yaml = await rootBundle.loadString('pubspec.yaml');
    final expected =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(yaml)!
            .group(1);
    expect(await AppVersion.get(), expected);
  });
}
