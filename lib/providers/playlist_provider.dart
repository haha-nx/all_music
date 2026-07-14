import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/storage_service.dart';

const _uuid = Uuid();

/// 歌单状态管理（SQLite 持久化）
class PlaylistNotifier extends StateNotifier<List<Playlist>> {
  PlaylistNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      state = await storageService.loadPlaylists();
    } catch (e) {
      // ignore: avoid_print
      print('PlaylistNotifier._init error: $e');
    }
  }

  /// 创建自建歌单
  void createPlaylist(String name) {
    final now = DateTime.now();
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name,
      type: PlaylistType.custom,
      createdAt: now,
      updatedAt: now,
    );
    state = [...state, playlist];
    _save();
  }

  /// 删除歌单
  void deletePlaylist(String id) {
    state = state.where((p) => p.id != id).toList();
    _save();
  }

  /// 重命名歌单
  void renamePlaylist(String id, String newName) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(name: newName, updatedAt: DateTime.now())
        else
          p,
    ];
    _save();
  }

  /// 添加歌曲到歌单
  void addSongToPlaylist(String playlistId, Song song) {
    state = [
      for (final p in state)
        if (p.id == playlistId)
          p.copyWith(
            songs: [...p.songs, song],
            updatedAt: DateTime.now(),
          )
        else
          p,
    ];
    _save();
  }

  /// 从歌单中移除歌曲
  void removeSongFromPlaylist(String playlistId, Song song) {
    state = [
      for (final p in state)
        if (p.id == playlistId)
          p.copyWith(
            songs: p.songs.where((s) => s.dedupeKey != song.dedupeKey).toList(),
            updatedAt: DateTime.now(),
          )
        else
          p,
    ];
    _save();
  }

  Future<void> _save() async => storageService.savePlaylists(state);
}

final playlistProvider = StateNotifierProvider<PlaylistNotifier, List<Playlist>>((ref) {
  return PlaylistNotifier();
});
