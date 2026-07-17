import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../music_source/core/track_adapter.dart';
import '../music_source/services/search_aggregator.dart';
import 'source_provider.dart';

/// 搜索状态
class SearchState {
  final List<Song> results;
  final bool isLoading;
  final String? error;
  final bool hasSearched;
  final List<String> failedSources;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.hasSearched = false,
    this.failedSources = const [],
  });

  SearchState copyWith({
    List<Song>? results,
    bool? isLoading,
    String? error,
    bool? hasSearched,
    List<String>? failedSources,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasSearched: hasSearched ?? this.hasSearched,
      failedSources: failedSources ?? this.failedSources,
    );
  }
}

/// 搜索状态管理（基于新的音乐源模块）
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref ref;
  Timer? _debounce;
  String _lastKeyword = '';

  SearchNotifier(this.ref) : super(const SearchState());

  /// 带防抖的搜索
  void searchWithDebounce(String keyword) {
    _debounce?.cancel();
    if (keyword.trim().isEmpty) {
      clear();
      return;
    }
    if (keyword.trim().length < 2) return;

    _debounce = Timer(const Duration(milliseconds: 400), () {
      search(keyword.trim());
    });
  }

  /// 跨音源搜索
  Future<void> search(String keyword) async {
    if (keyword.isEmpty || keyword.length < 2) return;
    if (_lastKeyword == keyword && !state.isLoading) return;
    _lastKeyword = keyword;

    state = state.copyWith(isLoading: true, error: null, failedSources: []);

    try {
      final sourceNotifier = ref.read(sourceProvider.notifier);
      final bridges = await sourceNotifier.manager.getReadyBridges();

      if (bridges.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          hasSearched: true,
          error: '没有可用音源，请在设置中导入并启用音源',
        );
        return;
      }

      final tracks = await SearchAggregator.search(bridges, keyword, limit: 20);
      final songs = TrackAdapter.toLegacySongs(tracks);

      state = state.copyWith(
        results: songs,
        isLoading: false,
        hasSearched: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        hasSearched: true,
      );
    }
  }

  void clear() {
    _debounce?.cancel();
    _lastKeyword = '';
    state = const SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
