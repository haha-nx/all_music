import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/cover_theme.dart';
import 'player_provider.dart';

/// 当前歌曲专辑封面的主题色（封面缺失/加载失败时为 null）
///
/// 封面 URL 变化时自动重新提取；extractCoverTheme 内部按 URL 缓存结果。
final coverThemeProvider = FutureProvider.autoDispose<CoverTheme?>((ref) {
  final coverUrl = ref.watch(playerProvider).currentSong?.albumCover;
  return extractCoverTheme(coverUrl);
});
