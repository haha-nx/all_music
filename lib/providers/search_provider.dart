import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../providers/source_provider.dart';
import '../services/source_api.dart';

/// 搜索状态
class SearchState {
  final List<Song> results;
  final bool isLoading;
  final String? error;
  final bool hasSearched;
  /// 搜索失败的音源名称列表
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

/// 搜索状态管理 — 通过导入的音源搜索
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref ref;
  SearchNotifier(this.ref) : super(const SearchState());

  /// 跨音源搜索
  Future<void> search(String keyword) async {
    state = state.copyWith(isLoading: true, error: null, failedSources: []);

    try {
      final sources = ref.read(sourceProvider).where((s) => s.enabled).toList();
      final allResults = <Song>[];
      final failed = <String>[];

      for (final source in sources) {
        try {
          final api = await SourceApi.create(source, ref);
          final results = await api.search(keyword, limit: 20);
          allResults.addAll(results);
        } catch (e) {
          failed.add(source.name);
        }
      }

      // 按去重 key 去重，保留第一个出现的
      final seen = <String>{};
      final deduped = <Song>[];
      for (final song in allResults) {
        if (seen.add(song.dedupeKey)) {
          deduped.add(song);
        }
      }

      state = state.copyWith(
        results: deduped,
        isLoading: false,
        hasSearched: true,
        failedSources: failed,
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
    state = const SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
