import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import '../models/source_type.dart';
import 'storage_service.dart';

/// 支持的音频文件扩展名
const _audioExtensions = {
  '.mp3', '.flac', '.wav', '.m4a', '.aac',
  '.ogg', '.wma', '.aiff', '.alac', '.opus',
};

/// 扫描结果
class ScanResult {
  final List<Song> songs;
  final int scannedFiles;
  final int skippedFiles;
  final List<String> errors;

  const ScanResult({
    this.songs = const [],
    this.scannedFiles = 0,
    this.skippedFiles = 0,
    this.errors = const [],
  });

  bool get hasNewFiles => songs.isNotEmpty;
}

/// 本地音频文件扫描引擎
///
/// 扫描手机存储中的音频文件，提取元数据，
/// 自动注册为 SourceType.local 的 Song 实例。
class LocalFileScanner {
  LocalFileScanner._();
  static final LocalFileScanner instance = LocalFileScanner._();

  /// 请求存储权限
  Future<bool> requestPermissions() async {
    // Android 13+ 使用细粒度媒体权限
    final audioStatus = await Permission.audio.status;
    if (audioStatus.isGranted) return true;
    if (audioStatus.isPermanentlyDenied) return false;

    final result = await Permission.audio.request();
    return result.isGranted;
  }

  /// 扫描所有可访问的音频目录
  Future<ScanResult> scanAll() async {
    final errors = <String>[];
    final allSongs = <Song>[];
    int scanned = 0;
    int skipped = 0;

    // 获取待扫描的目录列表
    final dirs = await _getScanDirectories();

    for (final dir in dirs) {
      if (!await dir.exists()) continue;

      try {
        final result = await _scanDirectory(dir, '');
        allSongs.addAll(result.songs);
        scanned += result.scannedFiles;
        skipped += result.skippedFiles;
        errors.addAll(result.errors);
      } catch (e) {
        errors.add('扫描 ${dir.path} 失败: $e');
      }
    }

    // 去重（同一文件路径只保留一个）
    final seen = <String>{};
    final deduped = <Song>[];
    for (final s in allSongs) {
      if (seen.add(s.id)) {
        deduped.add(s);
      }
    }

    return ScanResult(
      songs: deduped,
      scannedFiles: scanned,
      skippedFiles: skipped,
      errors: errors,
    );
  }

  /// 获取需要扫描的目录列表
  Future<List<Directory>> _getScanDirectories() async {
    final dirs = <Directory>[];

    try {
      // 应用文档目录（用户可直接放置文件）
      final appDocDir = await getApplicationDocumentsDirectory();
      dirs.add(Directory('${appDocDir.path}/Music'));

      // 外部存储根目录
      final extDirs = await getExternalStorageDirectories();
      if (extDirs != null && extDirs.isNotEmpty) {
        for (final d in extDirs) {
            dirs.add(Directory('${d.path}/Music'));
            dirs.add(Directory('${d.path}/Download'));
          }
      }

      // 常见音乐目录
      final commonPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Music',
        '/sdcard/Download',
      ];
      for (final path in commonPaths) {
        final d = Directory(path);
        if (await d.exists()) {
          if (!dirs.any((e) => e.path == path)) {
            dirs.add(d);
          }
        }
      }
    } catch (_) {
      // 目录枚举失败，静默
    }

    return dirs;
  }

  /// 递归扫描目录
  Future<ScanResult> _scanDirectory(Directory dir, String relativePath, {int maxDepth = 4}) async {
    final songs = <Song>[];
    int scanned = 0;
    int skipped = 0;
    final errors = <String>[];

    if (relativePath.split('/').length > maxDepth) {
      return ScanResult(songs: songs, scannedFiles: scanned, skippedFiles: skipped, errors: errors);
    }

    try {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        try {
          if (entity is File) {
            scanned++;
            final ext = entity.path.toLowerCase();
            final dot = ext.lastIndexOf('.');
            if (dot < 0 || !_audioExtensions.contains(ext.substring(dot))) {
              skipped++;
              continue;
            }

            final song = await _fileToSong(entity);
            if (song != null) {
              songs.add(song);
            } else {
              skipped++;
            }
          } else if (entity is Directory) {
            final subResult = await _scanDirectory(
              entity,
              '$relativePath/${entity.uri.pathSegments.last}',
              maxDepth: maxDepth,
            );
            songs.addAll(subResult.songs);
            scanned += subResult.scannedFiles;
            skipped += subResult.skippedFiles;
            errors.addAll(subResult.errors);
          }
        } catch (e) {
          errors.add('处理文件 ${entity.path} 失败: $e');
          skipped++;
        }
      }
    } catch (e) {
      errors.add('扫描目录 ${dir.path} 失败: $e');
    }

    return ScanResult(
      songs: songs,
      scannedFiles: scanned,
      skippedFiles: skipped,
      errors: errors,
    );
  }

  /// 将文件转换为 Song 模型
  Future<Song?> _fileToSong(File file) async {
    try {
      final path = file.path;
      final fileName = path.split('/').last.split('\\').last;
      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

      String title;
      String artist;

      // 尝试从 ID3v1 标签读取元数据
      final id3 = await _readId3v1(file);
      if (id3 != null) {
        title = id3['title']?.isNotEmpty == true ? id3['title']! : nameWithoutExt;
        artist = id3['artist']?.isNotEmpty == true ? id3['artist']! : '未知歌手';
      } else {
        // 从文件名解析: "Artist - Title" 格式
        final parts = _parseFileName(nameWithoutExt);
        title = parts.title;
        artist = parts.artist;
      }

      return Song(
        id: path, // 使用文件路径作为 ID（本地文件场景）
        source: SourceType.local,
        name: title,
        artist: artist,
        album: id3?['album'],
        duration: null, // 不做完整解码，耗时太长
        sourceId: 'builtin-local',
      );
    } catch (_) {
      return null;
    }
  }

  /// 读取 MP3 文件的 ID3v1 标签（最后 128 字节）
  Future<Map<String, String?>?> _readId3v1(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);

      // 获取文件大小
      final fileSize = await raf.length();
      if (fileSize < 128) {
        await raf.close();
        return null;
      }

      // 读取最后 128 字节
      await raf.setPosition(fileSize - 128);
      final bytes = await raf.read(128);
      await raf.close();

      // 检查 TAG 标记
      if (bytes.length < 128) return null;
      if (bytes[0] != 0x54 || bytes[1] != 0x41 || bytes[2] != 0x47) {
        return null; // 不是 "TAG"
      }

      // 解码 ISO-8859-1 编码的字段
      String readField(int start, int length) {
        final end = start + length;
        if (end > bytes.length) return '';
        final buffer = bytes.sublist(start, end);
        // 去除尾随空格和 null 字节
        final str = String.fromCharCodes(
          buffer.where((b) => b > 0x1F && b < 0x7F),
        ).trim();
        return str;
      }

      return {
        'title': readField(3, 30),
        'artist': readField(33, 30),
        'album': readField(63, 30),
        'year': readField(93, 4),
      };
    } catch (_) {
      return null;
    }
  }

  /// 从文件名解析歌名和歌手
  /// 支持: "Artist - Title", "Artist-Title", "Title - Artist"
  ({String title, String artist}) _parseFileName(String nameWithoutExt) {
    // 尝试 " - " 分隔符
    for (final sep in [' - ', '-', ' – ', '–', ' — ', '—']) {
      final parts = nameWithoutExt.split(sep);
      if (parts.length >= 2) {
        final first = parts[0].trim();
        final second = parts.sublist(1).join(sep).trim();
        if (first.isNotEmpty && second.isNotEmpty) {
          return (title: second, artist: first);
        }
      }
    }
    return (title: nameWithoutExt, artist: '未知歌手');
  }

  /// 保存扫描结果到数据库
  Future<void> saveToStorage(List<Song> songs) async {
    await storageService.saveLocalFiles(songs);
  }

  /// 加载已保存的本地文件
  Future<List<Song>> loadFromStorage() async {
    return storageService.loadLocalFiles();
  }
}
