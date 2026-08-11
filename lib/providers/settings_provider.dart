import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// 应用设置
class AppSettings {
  /// 默认播放音质（lx 标准：128k / 320k / flac）
  final String defaultQuality;

  const AppSettings({this.defaultQuality = '128k'});

  AppSettings copyWith({String? defaultQuality}) => AppSettings(
        defaultQuality: defaultQuality ?? this.defaultQuality,
      );
}

/// 设置状态管理（SQLite 键值持久化）
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final q = await storageService.getSetting('default_quality');
      if (q != null && q.isNotEmpty) {
        state = state.copyWith(defaultQuality: q);
      }
    } catch (_) {
      // 忽略初始化错误，使用默认值
    }
  }

  /// 设置默认音质
  Future<void> setDefaultQuality(String quality) async {
    state = state.copyWith(defaultQuality: quality);
    await storageService.setSetting('default_quality', quality);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
