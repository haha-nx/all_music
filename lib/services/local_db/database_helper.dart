import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../models/song.dart';
import '../../models/music_source.dart';
import '../../models/playlist.dart';
import '../../models/source_type.dart';

/// SQLite 数据库助手 — 单例，管理所有本地数据持久化
///
/// 替换原来的 SharedPreferences + JSON 方案，
/// 解决 1MB 单 key 限制，支持大量歌曲/歌单数据。
class DatabaseHelper {
  static const _dbName = 'all_music.db';
  static const _dbVersion = 2;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  /// 获取数据库实例（懒初始化）
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  /// 检查表中是否已存在某列
  Future<bool> _columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((row) => row['name'] == column);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: 添加 source_type 和 script_source 列（JS 源脚本支持）
      // 幂等检查：开发期间数据库可能已包含这些列（如从 v2 onCreate 创建后版本回退）
      if (!await _columnExists(db, 'music_sources', 'source_type')) {
        await db.execute(
          "ALTER TABLE music_sources ADD COLUMN source_type TEXT DEFAULT 'api'",
        );
      }
      if (!await _columnExists(db, 'music_sources', 'script_source')) {
        await db.execute(
          'ALTER TABLE music_sources ADD COLUMN script_source TEXT',
        );
      }
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // 音源表
    await db.execute('''
      CREATE TABLE music_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        api_url TEXT NOT NULL,
        token TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'api',
        script_source TEXT
      )
    ''');

    // 歌曲表（独立存储，供收藏/最近播放/歌单引用）
    await db.execute('''
      CREATE TABLE songs (
        id TEXT NOT NULL,
        source_key TEXT NOT NULL,
        name TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT,
        album_cover TEXT,
        duration_ms INTEGER,
        lyric_id TEXT,
        source_id TEXT,
        PRIMARY KEY (id, source_key)
      )
    ''');

    // 收藏表
    await db.execute('''
      CREATE TABLE favorites (
        song_id TEXT NOT NULL,
        source_key TEXT NOT NULL,
        added_at TEXT NOT NULL,
        PRIMARY KEY (song_id, source_key),
        FOREIGN KEY (song_id, source_key) REFERENCES songs(id, source_key)
      )
    ''');

    // 最近播放表
    await db.execute('''
      CREATE TABLE recently_played (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id TEXT NOT NULL,
        source_key TEXT NOT NULL,
        played_at TEXT NOT NULL,
        FOREIGN KEY (song_id, source_key) REFERENCES songs(id, source_key)
      )
    ''');

    // 歌单表
    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cover_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 歌单-歌曲关联表
    await db.execute('''
      CREATE TABLE playlist_songs (
        playlist_id TEXT NOT NULL,
        song_id TEXT NOT NULL,
        source_key TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (playlist_id, song_id, source_key),
        FOREIGN KEY (playlist_id) REFERENCES playlists(id),
        FOREIGN KEY (song_id, source_key) REFERENCES songs(id, source_key)
      )
    ''');
  }

  // ── 工具方法 ──

  Song _songFromRow(Map<String, dynamic> row) => Song(
    id: row['id'] as String,
    source: SourceType.fromKey(row['source_key'] as String),
    name: row['name'] as String,
    artist: row['artist'] as String,
    album: row['album'] as String?,
    albumCover: row['album_cover'] as String?,
    duration: row['duration_ms'] != null
        ? Duration(milliseconds: row['duration_ms'] as int)
        : null,
    lyricId: row['lyric_id'] as String?,
    sourceId: row['source_id'] as String?,
  );

  Map<String, dynamic> _songToRow(Song s) => {
    'id': s.id,
    'source_key': s.source.key,
    'name': s.name,
    'artist': s.artist,
    'album': s.album,
    'album_cover': s.albumCover,
    'duration_ms': s.duration?.inMilliseconds,
    'lyric_id': s.lyricId,
    'source_id': s.sourceId,
  };

  /// 保存歌曲（upsert），接受 Database 或 Transaction
  Future<void> _upsertSong(DatabaseExecutor db, Song song) async {
    await db.insert(
      'songs',
      _songToRow(song),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ══════════════════════════════════════════════
  // 音源 CRUD
  // ══════════════════════════════════════════════

  Future<List<MusicSource>> loadSources() async {
    final db = await database;
    final rows = await db.query('music_sources', orderBy: 'created_at ASC');
    return rows
        .map(
          (r) => MusicSource(
            id: r['id'] as String,
            name: r['name'] as String,
            apiUrl: r['api_url'] as String,
            token: r['token'] as String?,
            enabled: (r['enabled'] as int) == 1,
            createdAt: DateTime.parse(r['created_at'] as String),
            sourceType: _parseSourceType(r['source_type'] as String?),
            scriptSource: r['script_source'] as String?,
          ),
        )
        .toList();
  }

  MusicSourceType _parseSourceType(String? type) {
    if (type == null) return MusicSourceType.api;
    return MusicSourceType.values.firstWhere(
      (t) => t.name == type,
      orElse: () => MusicSourceType.api,
    );
  }

  Future<void> saveSources(List<MusicSource> sources) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('music_sources');
      for (final s in sources) {
        await txn.insert('music_sources', {
          'id': s.id,
          'name': s.name,
          'api_url': s.apiUrl,
          'token': s.token,
          'enabled': s.enabled ? 1 : 0,
          'created_at': s.createdAt.toIso8601String(),
          'source_type': s.sourceType.name,
          'script_source': s.scriptSource,
        });
      }
    });
  }

  // ══════════════════════════════════════════════
  // 收藏 CRUD
  // ══════════════════════════════════════════════

  Future<List<Song>> loadFavorites() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.* FROM songs s
      INNER JOIN favorites f ON s.id = f.song_id AND s.source_key = f.source_key
      ORDER BY f.added_at DESC
    ''');
    return rows.map(_songFromRow).toList();
  }

  Future<void> saveFavorites(List<Song> songs) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('favorites');
      for (final s in songs) {
        await _upsertSong(txn, s);
        await txn.insert('favorites', {
          'song_id': s.id,
          'source_key': s.source.key,
          'added_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> addFavorite(Song song) async {
    final db = await database;
    await _upsertSong(db, song);
    await db.insert('favorites', {
      'song_id': song.id,
      'source_key': song.source.key,
      'added_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeFavorite(Song song) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'song_id = ? AND source_key = ?',
      whereArgs: [song.id, song.source.key],
    );
  }

  // ══════════════════════════════════════════════
  // 最近播放 CRUD
  // ══════════════════════════════════════════════

  Future<List<Song>> loadRecentlyPlayed({int limit = 50}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT s.* FROM songs s
      INNER JOIN recently_played r ON s.id = r.song_id AND s.source_key = r.source_key
      ORDER BY r.played_at DESC
      LIMIT ?
    ''',
      [limit],
    );
    return rows.map(_songFromRow).toList();
  }

  Future<void> addToRecentlyPlayed(Song song) async {
    final db = await database;
    await _upsertSong(db, song);

    await db.transaction((txn) async {
      // 先删除旧记录（避免重复）
      await txn.delete(
        'recently_played',
        where: 'song_id = ? AND source_key = ?',
        whereArgs: [song.id, song.source.key],
      );
      // 插入新记录
      await txn.insert('recently_played', {
        'song_id': song.id,
        'source_key': song.source.key,
        'played_at': DateTime.now().toIso8601String(),
      });
      // 限制最多 50 条
      final count =
          Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM recently_played'),
          ) ??
          0;
      if (count > 50) {
        await txn.rawDelete('''
          DELETE FROM recently_played WHERE id NOT IN (
            SELECT id FROM recently_played ORDER BY played_at DESC LIMIT 50
          )
        ''');
      }
    });
  }

  Future<void> clearRecentlyPlayed() async {
    final db = await database;
    await db.delete('recently_played');
  }

  Future<void> saveRecentlyPlayed(List<Song> songs) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('recently_played');
      final now = DateTime.now().toIso8601String();
      for (final s in songs) {
        await _upsertSong(txn, s);
        await txn.insert('recently_played', {
          'song_id': s.id,
          'source_key': s.source.key,
          'played_at': now,
        });
      }
    });
  }

  // ══════════════════════════════════════════════
  // 歌单 CRUD
  // ══════════════════════════════════════════════

  Future<List<Playlist>> loadPlaylists() async {
    final db = await database;
    final playlistRows = await db.query('playlists', orderBy: 'created_at ASC');

    final result = <Playlist>[];
    for (final pr in playlistRows) {
      final songRows = await db.rawQuery(
        '''
        SELECT s.* FROM songs s
        INNER JOIN playlist_songs ps ON s.id = ps.song_id AND s.source_key = ps.source_key
        WHERE ps.playlist_id = ?
        ORDER BY ps.sort_order ASC
      ''',
        [pr['id']],
      );
      result.add(
        Playlist(
          id: pr['id'] as String,
          name: pr['name'] as String,
          coverUrl: pr['cover_url'] as String?,
          songs: songRows.map(_songFromRow).toList(),
          createdAt: DateTime.parse(pr['created_at'] as String),
          updatedAt: DateTime.parse(pr['updated_at'] as String),
        ),
      );
    }
    return result;
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    final db = await database;
    await db.transaction((txn) async {
      // 全量替换（简单但可靠）
      await txn.delete('playlist_songs');
      await txn.delete('playlists');

      for (final p in playlists) {
        await txn.insert('playlists', {
          'id': p.id,
          'name': p.name,
          'cover_url': p.coverUrl,
          'created_at': p.createdAt.toIso8601String(),
          'updated_at': p.updatedAt.toIso8601String(),
        });
        for (int i = 0; i < p.songs.length; i++) {
          final s = p.songs[i];
          await _upsertSong(txn, s);
          await txn.insert('playlist_songs', {
            'playlist_id': p.id,
            'song_id': s.id,
            'source_key': s.source.key,
            'sort_order': i,
          });
        }
      }
    });
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final db = await database;
    await _upsertSong(db, song);
    final maxOrder =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT MAX(sort_order) FROM playlist_songs WHERE playlist_id = ?',
            [playlistId],
          ),
        ) ??
        -1;
    await db.insert('playlist_songs', {
      'playlist_id': playlistId,
      'song_id': song.id,
      'source_key': song.source.key,
      'sort_order': maxOrder + 1,
    });
  }

  Future<void> removeSongFromPlaylist(String playlistId, Song song) async {
    final db = await database;
    await db.delete(
      'playlist_songs',
      where: 'playlist_id = ? AND song_id = ? AND source_key = ?',
      whereArgs: [playlistId, song.id, song.source.key],
    );
  }

  // ══════════════════════════════════════════════
  // 本地文件 CRUD
  // ══════════════════════════════════════════════

  Future<List<Song>> loadLocalFiles() async {
    final db = await database;
    final rows = await db.query(
      'songs',
      where: 'source_key = ?',
      whereArgs: ['local'],
      orderBy: 'artist ASC, name ASC',
    );
    return rows.map(_songFromRow).toList();
  }

  Future<void> saveLocalFiles(List<Song> songs) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('songs', where: 'source_key = ?', whereArgs: ['local']);
      for (final s in songs) {
        await txn.insert('songs', _songToRow(s));
      }
    });
  }

  /// 返回数据库总行数，用于监控数据量
  Future<int> estimateStorageBytes() async {
    try {
      final db = await database;
      final counts = await Future.wait([
        db.rawQuery('SELECT COUNT(*) AS c FROM songs'),
        db.rawQuery('SELECT COUNT(*) AS c FROM favorites'),
        db.rawQuery('SELECT COUNT(*) AS c FROM recently_played'),
        db.rawQuery('SELECT COUNT(*) AS c FROM playlists'),
        db.rawQuery('SELECT COUNT(*) AS c FROM playlist_songs'),
        db.rawQuery('SELECT COUNT(*) AS c FROM music_sources'),
      ]);
      int total = 0;
      for (final r in counts) {
        total += Sqflite.firstIntValue(r) ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
