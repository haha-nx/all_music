import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/lx_bridge.dart';
import '../core/music_backend.dart';
import '../models/music_track.dart';
import '../models/source_definition.dart';
import '../services/download_manager.dart';
import '../services/search_aggregator.dart';
import '../services/source_manager.dart';

/// 全局 Dio 实例
final _dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
  ));
});

// ═══════════════════════════════════════
// Source Provider
// ═══════════════════════════════════════

/// 音源列表状态
final sourceListProvider =
    StateNotifierProvider<SourceListNotifier, List<SourceDefinition>>((ref) {
  final dio = ref.watch(_dioProvider);
  return SourceListNotifier(dio);
});

class SourceListNotifier extends StateNotifier<List<SourceDefinition>> {
  final SourceManager _manager;

  SourceListNotifier(Dio dio)
      : _manager = SourceManager(dio),
        super([]) {
    _manager.onChanged = (sources) => state = sources;
    _init();
  }

  Future<void> _init() async {
    // 音源全部由用户导入，不做内置初始化
  }

  SourceManager get manager => _manager;

  /// 获取音源后端
  Future<LxBridge?> getBridge(String sourceId) =>
      _manager.getBridge(sourceId);

  /// 获取音源后端（任意类型：JS 或 direct）
  Future<MusicBackend?> getBackend(String sourceId) =>
      _manager.getBackend(sourceId);

  /// 导入脚本
  Future<SourceImportResult> importScript(String script) =>
      _manager.importFromScript(script);

  /// 从URL导入
  Future<SourceImportResult> importFromUrl(String url) =>
      _manager.importFromUrl(url);

  /// 移除/禁用
  void remove(String id) => _manager.removeSource(id);

  /// 切换启用
  void toggle(String id) => _manager.toggleEnabled(id);

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════
// Search Provider
// ═══════════════════════════════════════

/// 搜索结果状态
class SearchState {
  final List<MusicTrack> results;
  final bool loading;
  final String? error;
  final String? keyword;

  const SearchState({
    this.results = const [],
    this.loading = false,
    this.error,
    this.keyword,
  });

  SearchState copyWith({
    List<MusicTrack>? results,
    bool? loading,
    String? error,
    String? keyword,
  }) {
    return SearchState(
      results: results ?? this.results,
      loading: loading ?? this.loading,
      error: error,
      keyword: keyword ?? this.keyword,
    );
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchNotifier(this._ref) : super(const SearchState());

  /// 执行跨源搜索
  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(loading: true, keyword: keyword, error: null);

    try {
      final sourceNotifier = _ref.read(sourceListProvider.notifier);
      final bridges = await sourceNotifier.manager.getReadyBridges();

      if (bridges.isEmpty) {
        state = state.copyWith(
          loading: false,
          error: '没有可用的音源，请先导入或启用音源',
        );
        return;
      }

      final results = await SearchAggregator.search(bridges, keyword);
      state = state.copyWith(loading: false, results: results);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void clear() => state = const SearchState();
}

// ═══════════════════════════════════════
// Download Provider
// ═══════════════════════════════════════

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, List<DownloadTask>>((ref) {
  final dio = ref.watch(_dioProvider);
  return DownloadNotifier(dio);
});

class DownloadNotifier extends StateNotifier<List<DownloadTask>> {
  final DownloadManager _manager;

  DownloadNotifier(Dio dio)
      : _manager = DownloadManager(dio),
        super([]) {
    _manager.onChanged = (tasks) => state = tasks;
  }

  DownloadManager get manager => _manager;

  void addAndStart(MusicTrack track, String url, {String quality = '128k'}) {
    final task = _manager.addTask(track, url, quality: quality);
    _manager.startDownload(task);
  }

  void cancel(DownloadTask task) => _manager.cancelDownload(task);
  void remove(DownloadTask task) => _manager.removeTask(task);
  void clearCompleted() => _manager.clearCompleted();
}

// ═══════════════════════════════════════
// Built-in Sources (已移除 — 音源全部由用户导入)
// ═══════════════════════════════════════
