import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../models/song.dart';
import '../../models/music_source.dart';
import '../../models/playlist.dart';
import '../../models/source_type.dart';

/// SQLite 数据库助手 — 单例，管理所有本地数据持久化
class DatabaseHelper {
  static const _dbName = 'all_music.db';
  static const _dbVersion = 5;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  /// 获取数据库实例（懒初始化）
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    // 运行时安全检查：确保旧 schema 列已被移除
    await _ensureSchemaClean(_db!);
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

  /// 运行时 schema 安全检查 — 如果旧列（api_url/source_type/token）仍存在，重建表
  /// 这确保即使 onUpgrade 因缓存/热重启没触发，schema 也能被修复
  Future<void> _ensureSchemaClean(Database db) async {
    final hasApiUrl = await _columnExists(db, 'music_sources', 'api_url');
    if (!hasApiUrl) return; // schema 已经干净，无需处理

    // ignore: avoid_print
    print('[DatabaseHelper] 发现旧 schema 列 api_url，重建 music_sources 表');
    await db.execute('''
      CREATE TABLE music_sources_v4 (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        script_url TEXT,
        script_source TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        sources_json TEXT,
        version TEXT,
        author TEXT,
        description TEXT
      )
    ''');
    await db.execute('''
      INSERT INTO music_sources_v4 (id, name, script_url, script_source, enabled, created_at, sources_json, version, author, description)
      SELECT id, name, script_url, script_source, enabled, created_at, sources_json, version, author, description
      FROM music_sources
      WHERE script_source IS NOT NULL AND script_source != ''
    ''');
    await db.execute('DROP TABLE music_sources');
    await db.execute('ALTER TABLE music_sources_v4 RENAME TO music_sources');
    // ignore: avoid_print
    print('[DatabaseHelper] music_sources 表重建完成');
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
      // v2: 添加 source_type 和 script_source 列
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
    if (oldVersion < 3) {
      // v3: 添加源能力字段（如果从 v1 直接升级到 v4，这段仍需执行）
      // 但对于从 v3 升级到 v4 的情况，下面 v4 迁移会重建表
      if (!await _columnExists(db, 'music_sources', 'sources_json')) {
        await db.execute(
          'ALTER TABLE music_sources ADD COLUMN sources_json TEXT',
        );
      }
      if (!await _columnExists(db, 'music_sources', 'version')) {
        await db.execute('ALTER TABLE music_sources ADD COLUMN version TEXT');
      }
      if (!await _columnExists(db, 'music_sources', 'author')) {
        await db.execute('ALTER TABLE music_sources ADD COLUMN author TEXT');
      }
      if (!await _columnExists(db, 'music_sources', 'description')) {
        await db.execute(
          'ALTER TABLE music_sources ADD COLUMN description TEXT',
        );
      }
      if (!await _columnExists(db, 'music_sources', 'script_url')) {
        await db.execute(
          'ALTER TABLE music_sources ADD COLUMN script_url TEXT',
        );
      }
      if (!await _columnExists(db, 'songs', 'source_key_extra')) {
        await db.execute('ALTER TABLE songs ADD COLUMN source_key_extra TEXT');
      }
    }
    if (oldVersion < 4) {
      // v4: 重建 music_sources 表 — 去掉 api_url NOT NULL 约束
      // v3 的 ALTER TABLE 方式只添加了新列，没处理旧列的 NOT NULL 约束
      // 用重建表法：创建新结构 → 复制数据 → 删除旧表 → 重命名
      final hasApiUrl = await _columnExists(db, 'music_sources', 'api_url');
      if (hasApiUrl) {
        await db.execute('''
          CREATE TABLE music_sources_v4 (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            script_url TEXT,
            script_source TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            sources_json TEXT,
            version TEXT,
            author TEXT,
            description TEXT
          )
        ''');
        // 只保留有 script_source 的脚本源，丢弃旧 REST API 源
        await db.execute('''
          INSERT INTO music_sources_v4 (id, name, script_url, script_source, enabled, created_at, sources_json, version, author, description)
          SELECT id, name, script_url, script_source, enabled, created_at, sources_json, version, author, description
          FROM music_sources
          WHERE script_source IS NOT NULL AND script_source != ''
        ''');
        await db.execute('DROP TABLE music_sources');
        await db.execute(
          'ALTER TABLE music_sources_v4 RENAME TO music_sources',
        );
      }
    }

    if (oldVersion < 5) {
      // v5: 新增设置表（默认音质等）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // 设置表（键值对）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // 音源表（v3：只支持脚本源）
    await db.execute('''
      CREATE TABLE music_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        script_url TEXT,
        script_source TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        sources_json TEXT,
        version TEXT,
        author TEXT,
        description TEXT
      )
    ''');

    // 歌曲表
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
        source_key_extra TEXT,
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
    sourceKey: row['source_key_extra'] as String?,
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
    'source_key_extra': s.sourceKey,
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
  // 设置 CRUD（键值对）
  // ══════════════════════════════════════════════

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ══════════════════════════════════════════════
  // 音源 CRUD
  // ══════════════════════════════════════════════

  Future<List<MusicSource>> loadSources() async {
    final db = await database;
    final rows = await db.query('music_sources', orderBy: 'created_at ASC');
    return rows.map((r) => MusicSource.fromMap(r)).toList();
  }

  Future<void> saveSources(List<MusicSource> sources) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('music_sources');
      // 防御性去重：按 id 保留最后一个，避免出现重复主键导致写入崩溃
      final seen = <String>{};
      final unique = <MusicSource>[];
      for (final s in sources) {
        if (seen.contains(s.id)) continue;
        seen.add(s.id);
        unique.add(s);
      }
      for (final s in unique) {
        await txn.insert(
          'music_sources',
          s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
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
      await txn.delete(
        'recently_played',
        where: 'song_id = ? AND source_key = ?',
        whereArgs: [song.id, song.source.key],
      );
      await txn.insert('recently_played', {
        'song_id': song.id,
        'source_key': song.source.key,
        'played_at': DateTime.now().toIso8601String(),
      });
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
