import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../music_source/core/music_backend.dart';
import '../music_source/models/music_list.dart';
import 'source_provider.dart';

/// 单个音源的榜单分组
class SourceLists {
  final String sourceId;
  final String sourceName;
  final List<MusicListInfo> lists;

  const SourceLists({
    required this.sourceId,
    required this.sourceName,
    required this.lists,
  });
}

/// 榜单聚合状态
class ListsState {
  final List<SourceLists> sections;
  final bool isLoading;
  final String? error;

  const ListsState({
    this.sections = const [],
    this.isLoading = false,
    this.error,
  });

  ListsState copyWith({
    List<SourceLists>? sections,
    bool? isLoading,
    String? error,
  }) {
    return ListsState(
      sections: sections ?? this.sections,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 是否有榜单数据
  bool get isEmpty => sections.isEmpty;

  /// 总榜单数
  int get totalCount =>
      sections.fold(0, (sum, s) => sum + s.lists.length);
}

/// 榜单状态管理 — 聚合所有启用音源的排行榜
class ListsNotifier extends StateNotifier<ListsState> {
  final Ref ref;

  ListsNotifier(this.ref) : super(const ListsState());

  /// 刷新所有音源的榜单（并行拉取，按源分组）
  Future<void> refresh() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final sourceNotifier = ref.read(sourceProvider.notifier);
      final bridges = await sourceNotifier.manager.getReadyListBridges();

      if (bridges.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: '没有支持排行榜的音源，请在音源中心导入标准 LX 音源',
        );
        return;
      }

      final futures = bridges.map((bridge) async {
        try {
          final lists = await bridge.list(limit: 30);
          return (bridge: bridge, lists: lists);
        } catch (e) {
          return (bridge: bridge, lists: <MusicListInfo>[]);
        }
      });

      final results = await Future.wait(futures);
      final sections = <SourceLists>[];

      for (final r in results) {
        final lists = r.lists;
        if (lists.isEmpty) continue;

        // 按源名分组（bridge.sourceId 映射到显示名）
        final name = _sourceName(r.bridge);
        final existing = sections
            .where((s) => s.sourceId == r.bridge.sourceId)
            .firstOrNull;
        if (existing != null) {
          sections[sections.indexOf(existing)] = SourceLists(
            sourceId: existing.sourceId,
            sourceName: existing.sourceName,
            lists: [...existing.lists, ...lists],
          );
        } else {
          sections.add(SourceLists(
            sourceId: r.bridge.sourceId,
            sourceName: name,
            lists: lists,
          ));
        }
      }

      state = state.copyWith(
        sections: sections,
        isLoading: false,
        error: sections.isEmpty ? '没有获取到榜单数据' : null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '获取榜单失败: $e',
      );
    }
  }

  String _sourceName(MusicBackend bridge) {
    final sources = ref.read(sourceProvider);
    for (final s in sources) {
      if (s.id == bridge.sourceId) return s.name;
    }
    return bridge.sourceId;
  }
}

final listsProvider =
    StateNotifierProvider<ListsNotifier, ListsState>((ref) {
  return ListsNotifier(ref);
});
