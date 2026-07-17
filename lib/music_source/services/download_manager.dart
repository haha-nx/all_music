import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/music_track.dart';

/// 下载任务状态
enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
}

/// 下载任务
class DownloadTask {
  final MusicTrack track;
  final String url;
  final String quality;
  DownloadStatus status = DownloadStatus.pending;
  double progress = 0.0;
  String? error;
  String? filePath;

  DownloadTask({
    required this.track,
    required this.url,
    this.quality = '128k',
  });

  String get fileName {
    final ext = p.extension(url.split('?').first);
    final safeName = '${track.artist} - ${track.title}'
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$safeName${ext.isNotEmpty ? ext : '.mp3'}';
  }
}

/// 音乐下载管理器
///
/// 支持并发下载、进度跟踪、取消任务。
class DownloadManager {
  final Dio _dio;

  final List<DownloadTask> _tasks = [];
  CancelToken? _cancelToken;

  /// 任务列表变更回调
  void Function(List<DownloadTask> tasks)? onChanged;

  DownloadManager(this._dio);

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  /// 添加下载任务
  DownloadTask addTask(MusicTrack track, String url, {String quality = '128k'}) {
    // 检查重复
    final existing = _tasks.where(
      (t) => t.track.id == track.id && t.track.sourceId == track.sourceId,
    );
    if (existing.isNotEmpty) return existing.first;

    final task = DownloadTask(track: track, url: url, quality: quality);
    _tasks.add(task);
    onChanged?.call(tasks);
    return task;
  }

  /// 开始下载
  Future<void> startDownload(DownloadTask task) async {
    if (task.status == DownloadStatus.downloading) return;

    task.status = DownloadStatus.downloading;
    task.progress = 0.0;
    task.error = null;
    onChanged?.call(tasks);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory(p.join(dir.path, 'Music'));
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final filePath = p.join(musicDir.path, task.fileName);
      _cancelToken = CancelToken();

      await _dio.download(
        task.url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            task.progress = received / total;
            onChanged?.call(tasks);
          }
        },
      );

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.filePath = filePath;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.failed;
        task.error = '已取消';
      } else {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
      }
    }

    onChanged?.call(tasks);
  }

  /// 取消下载
  void cancelDownload(DownloadTask task) {
    _cancelToken?.cancel();
    task.status = DownloadStatus.failed;
    task.error = '已取消';
    onChanged?.call(tasks);
  }

  /// 移除任务
  void removeTask(DownloadTask task) {
    if (task.status == DownloadStatus.downloading) {
      cancelDownload(task);
    }
    _tasks.remove(task);
    onChanged?.call(tasks);
  }

  /// 清除已完成的任务
  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    onChanged?.call(tasks);
  }
}
