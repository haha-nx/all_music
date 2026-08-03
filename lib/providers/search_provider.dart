import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../music_source/core/track_adapter.dart';
import '../music_source/models/music_track.dart';
import '../music_source/services/search_aggregator.dart';
import 'source_provider.dart';

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
      final sourceNotifier = ref.read(sourceProvider.notifier);

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

      final tracks = await SearchAggregator.search(
        bridges,
        keyword,
        limit: 20,
        type: type,
      );
      final songs = TrackAdapter.toLegacySongs(tracks);

      if (tracks.isEmpty) {
        // 收集各后端的错误信息，便于在真机上排查（网络/接口问题等）
        final errs = bridges
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
