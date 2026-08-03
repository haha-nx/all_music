import '../models/music_source.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import 'local_db/database_helper.dart';

/// 本地持久化存储服务 — SQLite 后端
///
/// 替代了原来的 SharedPreferences + JSON 方案，
/// 解决了单 key 1MB 限制并支持海量数据。
class StorageService {
  DatabaseHelper get _db => DatabaseHelper.instance;

  /// 初始化数据库（首次调用时自动创建表和索引）
  Future<void> init() async {
    await _db.database; // 触发懒初始化
  }

  // ── 音源 ──

  Future<List<MusicSource>> loadSources() => _db.loadSources();
  Future<void> saveSources(List<MusicSource> sources) => _db.saveSources(sources);

  // ── 收藏 ──

  Future<List<Song>> loadFavorites() => _db.loadFavorites();
  Future<void> saveFavorites(List<Song> songs) => _db.saveFavorites(songs);

  // ── 最近播放 ──

  Future<List<Song>> loadRecentlyPlayed() => _db.loadRecentlyPlayed();
  Future<void> saveRecentlyPlayed(List<Song> songs) => _db.saveRecentlyPlayed(songs);
  Future<void> addToRecentlyPlayed(Song song) => _db.addToRecentlyPlayed(song);
  Future<void> clearRecentlyPlayed() => _db.clearRecentlyPlayed();

  // ── 歌单 ──

  Future<List<Playlist>> loadPlaylists() => _db.loadPlaylists();
  Future<void> savePlaylists(List<Playlist> playlists) => _db.savePlaylists(playlists);
  Future<void> addSongToPlaylist(String playlistId, Song song) =>
      _db.addSongToPlaylist(playlistId, song);
  Future<void> removeSongFromPlaylist(String playlistId, Song song) =>
      _db.removeSongFromPlaylist(playlistId, song);

  // ── 设置 ──

  Future<String?> getSetting(String key) => _db.getSetting(key);
  Future<void> setSetting(String key, String value) =>
      _db.setSetting(key, value);

  // ── 本地文件 ──

  Future<List<Song>> loadLocalFiles() => _db.loadLocalFiles();
  Future<void> saveLocalFiles(List<Song> songs) => _db.saveLocalFiles(songs);

  // ── 工具 ──

  Future<int> estimateStorageBytes() => _db.estimateStorageBytes();
  Future<void> close() => _db.close();
}

/// 全局单例
final storageService = StorageService();
