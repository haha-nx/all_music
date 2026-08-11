import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../music_source/builtin/builtin_platforms.dart';
import '../music_source/models/music_list.dart';
import '../music_source/providers/music_source_provider.dart';
import 'account_center_provider.dart';

/// 单个登录平台的「我喜欢的音乐」分组
class PlatformPlaylistGroup {
  final String sourceId;
  final String sourceKey;
  final String sourceName;
  final List<MusicListInfo> lists;

  const PlatformPlaylistGroup({
    required this.sourceId,
    required this.sourceKey,
    required this.sourceName,
    required this.lists,
  });
}

/// 登录平台「我喜欢的音乐」分组聚合
///
/// 每个平台一组、只包含**已登录**的平台（未登录不显示）。
/// 登录态 / 启用音源变化时自动重建刷新。
class AccountPlaylistsNotifier
    extends StateNotifier<List<PlatformPlaylistGroup>> {
  final Ref ref;

  AccountPlaylistsNotifier(this.ref) : super(const []) {
    _refresh();
  }

  Future<void> _refresh() async {
    final notifier = ref.read(sourceListProvider.notifier);
    final loggedIn = ref.read(accountCenterProvider);
    final groups = <PlatformPlaylistGroup>[];
    for (final source in notifier.enabledSources) {
      if (!source.id.startsWith('builtin_')) continue;
      final platform = kBuiltinPlatforms
          .where((p) => p.id == source.id)
          .firstOrNull;
      if (platform == null) continue;
      // 只有已登录的平台才显示
      if (!(loggedIn[platform.sourceKey]?.isLoggedIn ?? false)) continue;

      final backend = await notifier.getBackend(source.id);
      if (backend == null) continue;
      try {
        final lists = await backend.list(limit: 20);
        // ignore: avoid_print
        print('[我的歌单] ${platform.sourceKey} 拉到 ${lists.length} 条');
        if (lists.isNotEmpty) {
          groups.add(PlatformPlaylistGroup(
            sourceId: source.id,
            sourceKey: platform.sourceKey,
            sourceName: platform.name,
            lists: lists,
          ));
        }
      } catch (e) {
        // ignore: avoid_print
        print('[我的歌单] ${platform.sourceKey} 拉取失败: $e');
      }
    }
    if (!mounted) return;
    state = groups;
  }
}

final accountPlaylistsProvider =
    StateNotifierProvider<AccountPlaylistsNotifier, List<PlatformPlaylistGroup>>((
  ref,
) {
  // 登录态 / 启用音源变化时重建 notifier 并重新拉取
  ref.watch(accountCenterProvider);
  ref.watch(sourceListProvider);
  return AccountPlaylistsNotifier(ref);
});
