import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../config/constants.dart';
import '../../../widgets/glass_panel.dart';
import '../models/music_track.dart';
import '../providers/music_source_provider.dart';
import '../services/download_manager.dart';

/// 下载管理页
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶栏
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.w, AppSizes.paddingH, 8.w),
              child: Row(
                children: [
                  GlassPanel(
                    blur: 8,
                    circle: true,
                    tintColor: AppColors.surfaceLight,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary, size: 18.sp),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '下载管理',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (tasks.isNotEmpty)
                    GlassPanel(
                      blur: 8,
                      circle: true,
                      tintColor: AppColors.surfaceLight,
                      child: IconButton(
                        icon: Icon(Icons.delete_sweep_rounded,
                            color: AppColors.textSecondary, size: 18.sp),
                        onPressed: () =>
                            ref.read(downloadProvider.notifier).clearCompleted(),
                      ),
                    ),
                ],
              ),
            ),

            // 任务列表
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_for_offline_rounded,
                              size: 56.sp, color: AppColors.textTertiary),
                          SizedBox(height: 16.w),
                          Text(
                            '暂无下载任务\n在歌曲菜单中点击「下载」开始',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: 40.w),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _DownloadTaskTile(task: task);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;

  const _DownloadTaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(downloadProvider.notifier);
    final isDone = task.status == DownloadStatus.completed;
    final isFailed = task.status == DownloadStatus.failed;
    final isDownloading = task.status == DownloadStatus.downloading;

    final statusText = switch (task.status) {
      DownloadStatus.pending => '等待中',
      DownloadStatus.downloading =>
        '${(task.progress * 100).toStringAsFixed(0)}%',
      DownloadStatus.completed => '已完成',
      DownloadStatus.failed => '失败：${task.error ?? '未知错误'}',
    };

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.paddingH,
        vertical: 6.w,
      ),
      child: GlassPanel(
        blur: 10,
        borderRadius: 14,
        tintColor: AppColors.surfaceLight,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.accentPurple.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                  child: Icon(
                    isDone
                        ? Icons.check_rounded
                        : isFailed
                            ? Icons.error_outline_rounded
                            : Icons.music_note_rounded,
                    color: isDone
                        ? AppColors.accentGreen
                        : isFailed
                            ? AppColors.error
                            : AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.w),
                    Text(
                      '${task.track.artist} · ${_qualityLabel(task.quality)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (isDownloading || task.status == DownloadStatus.pending) ...[
                      SizedBox(height: 6.w),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 4.w,
                          backgroundColor: AppColors.surfaceDark,
                          color: AppColors.primary,
                        ),
                      ),
                    ] else ...[
                      SizedBox(height: 4.w),
                      Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDone
                              ? AppColors.accentGreen
                              : isFailed
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              if (isDownloading || task.status == DownloadStatus.pending)
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 20.sp),
                  onPressed: () => notifier.cancel(task),
                )
              else
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: AppColors.textSecondary, size: 20.sp),
                  onPressed: () => notifier.remove(task),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _qualityLabel(String q) {
    for (final quality in MusicQuality.values) {
      if (quality.value == q) return quality.label;
    }
    return q;
  }
}
