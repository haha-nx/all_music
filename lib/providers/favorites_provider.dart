import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/storage_service.dart';

/// 收藏和最近播放状态
class FavoritesState {
  final List<Song> favorites;
  final List<Song> recentlyPlayed;
  static const int maxRecent = 50;

  const FavoritesState({
    this.favorites = const [],
    this.recentlyPlayed = const [],
  });

  FavoritesState copyWith({
    List<Song>? favorites,
    List<Song>? recentlyPlayed,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
    );
  }
}

/// 收藏和最近播放管理（SQLite 持久化）
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier() : super(const FavoritesState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final favorites = await storageService.loadFavorites();
      final recent = await storageService.loadRecentlyPlayed();
      if (mounted) {
        state = FavoritesState(favorites: favorites, recentlyPlayed: recent);
      }
    } catch (e) {
      // ignore: avoid_print
      print('FavoritesNotifier._init error: $e');
    }
  }

  /// 收藏/取消收藏歌曲
  void toggleFavorite(Song song) {
    final index = state.favorites.indexWhere((s) => s.dedupeKey == song.dedupeKey);
    if (index >= 0) {
      state = state.copyWith(
        favorites: state.favorites.where((s) => s.dedupeKey != song.dedupeKey).toList(),
      );
    } else {
      state = state.copyWith(favorites: [...state.favorites, song]);
    }
    _save();
  }

  /// 是否已收藏
  bool isFavorite(Song song) {
    return state.favorites.any((s) => s.dedupeKey == song.dedupeKey);
  }

  /// 添加到最近播放
  void addToRecent(Song song) {
    final updated = [song, ...state.recentlyPlayed.where((s) => s.dedupeKey != song.dedupeKey)];
    state = state.copyWith(
      recentlyPlayed: updated.take(FavoritesState.maxRecent).toList(),
    );
    _save();
  }

  /// 清空最近播放
  void clearRecent() {
    state = state.copyWith(recentlyPlayed: []);
    _save();
  }

  Future<void> _save() async {
    await storageService.saveFavorites(state.favorites);
    await storageService.saveRecentlyPlayed(state.recentlyPlayed);
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier();
});
