import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../music_source/core/track_adapter.dart';
import '../music_source/models/music_track.dart';
import '../music_source/providers/music_source_provider.dart';
import '../music_source/services/search_aggregator.dart';
import 'account_center_provider.dart';

/// 内置平台 sourceKey 集合：用于搜索过滤（未登录的内置源跳过）
const Set<String> kBuiltinSourceKeys = {'wy', 'tx', 'kg', 'kw', 'mg'};

/// 搜索状态
class SearchState {
  final List<Song> results;

  /// 当前搜索类型（单曲/专辑/歌手/歌单）
  final SearchType searchType;
  final bool isLoading;
  final String? error;
  final bool hasSearched;
  final List<String> failedSources;

  const SearchState({
    this.results = const [],
    this.searchType = SearchType.song,
    this.isLoading = false,
    this.error,
    this.hasSearched = false,
    this.failedSources = const [],
  });

  SearchState copyWith({
    List<Song>? results,
    SearchType? searchType,
    bool? isLoading,
    String? error,
    bool? hasSearched,
    List<String>? failedSources,
  }) {
    return SearchState(
      results: results ?? this.results,
      searchType: searchType ?? this.searchType,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasSearched: hasSearched ?? this.hasSearched,
      failedSources: failedSources ?? this.failedSources,
    );
  }
}

/// 搜索状态管理
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref ref;
  Timer? _debounce;
  String _lastKeyword = '';
  SearchType _lastType = SearchType.song;

  SearchNotifier(this.ref) : super(const SearchState());

  void searchWithDebounce(String keyword) {
    _debounce?.cancel();
    if (keyword.trim().isEmpty) {
      clear();
      return;
    }
    if (keyword.trim().length < 2) return;

    _debounce = Timer(const Duration(milliseconds: 400), () {
      search(keyword.trim(), type: state.searchType);
    });
  }

  /// 切换搜索类型（切换后立即用当前关键词重新搜索）
  void setSearchType(SearchType type) {
    if (state.searchType == type) return;
    state = state.copyWith(searchType: type, results: [], hasSearched: false);
    final keyword = _lastKeyword;
    if (keyword.isNotEmpty) {
      search(keyword, type: type);
    }
  }

  Future<void> search(String keyword, {SearchType type = SearchType.song}) async {
    if (keyword.isEmpty || keyword.length < 2) return;
    if (_lastKeyword == keyword && _lastType == type && !state.isLoading) return;
    _lastKeyword = keyword;
    _lastType = type;

    state = state.copyWith(isLoading: true, error: null, failedSources: []);

    try {
      final sourceNotifier = ref.read(sourceListProvider.notifier);

      // 检查引擎就绪状态
      if (!sourceNotifier.isEngineReady) {
        if (sourceNotifier.readyState == SourceReadyState.loading) {
          state = state.copyWith(
            isLoading: false,
            hasSearched: true,
            error: '音源引擎正在初始化中，请稍后...',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            hasSearched: true,
            error: '音源引擎初始化失败'
                '${sourceNotifier.readyError != null ? "：${sourceNotifier.readyError}" : ""}'
                '\n请在设置 → 音源中心检查音源状态',
          );
        }
        return;
      }

      final bridges = await sourceNotifier.manager.getReadyBridges();
      if (bridges.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          hasSearched: true,
          error: '没有可用音源，请在设置 → 音源中心导入并启用音源',
        );
        return;
      }

      final searchBridges =
          bridges.where((b) => b.searchKeys.isNotEmpty).toList();
      if (searchBridges.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          hasSearched: true,
          error: '当前没有支持搜索的音源，请导入带 search 能力的 LX 音源',
        );
        return;
      }

      // 只搜索已登录账号的平台：内置源（wy/tx/kg/kw/mg）若未登录则跳过；
      // 脚本源（LxBridge）不受账号限制，保留参与搜索。
      final loggedInKeys = ref
          .read(accountCenterProvider)
          .entries
          .where((e) => e.value.isLoggedIn)
          .map((e) => e.key)
          .toSet();
      final filteredBridges = searchBridges.where((b) {
        final keys = b.searchKeys;
        final hasBuiltin = keys.any(kBuiltinSourceKeys.contains);
        if (!hasBuiltin) return true; // 脚本源保留
        return keys.any(loggedInKeys.contains);
      }).toList();
      if (filteredBridges.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          hasSearched: true,
          error: '没有已登录账号的音源，请先在设置 → 账号中心登录',
        );
        return;
      }

      final tracks = await SearchAggregator.search(
        filteredBridges,
        keyword,
        limit: 20,
        type: type,
      );
      final songs = TrackAdapter.toLegacySongs(tracks);

      if (tracks.isEmpty) {
        // 收集各后端的错误信息，便于在真机上排查（网络/接口问题等）
        final errs = searchBridges
            .where((b) => b.lastError != null && b.lastError!.isNotEmpty)
            .map((b) => b.lastError!)
            .toSet()
            .toList();
        state = state.copyWith(
          results: songs,
          isLoading: false,
          hasSearched: true,
          error: errs.isNotEmpty
              ? '搜索无结果：${errs.join('；')}'
              : '未找到与「$keyword」相关的${type.label}',
        );
        return;
      }

      state = state.copyWith(
        results: songs,
        isLoading: false,
        hasSearched: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '搜索异常: $e',
        hasSearched: true,
      );
    }
  }

  void clear() {
    _debounce?.cancel();
    _lastKeyword = '';
    _lastType = SearchType.song;
    state = const SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
