import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../config/constants.dart';
import '../../widgets/glass_panel.dart';
import '../models/source_definition.dart';
import '../providers/music_source_provider.dart';

/// 音源管理中心
///
/// 查看、启用/禁用、导入用户音源。
class SourceHubScreen extends ConsumerStatefulWidget {
  const SourceHubScreen({super.key});

  @override
  ConsumerState<SourceHubScreen> createState() => _SourceHubScreenState();
}

class _SourceHubScreenState extends ConsumerState<SourceHubScreen> {
  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourceListProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('音源中心'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSizes.paddingH),
        children: [
          // ── 头部说明 ──
          _SectionHeader(title: '已导入音源', subtitle: '启用音源后可在搜索中使用。可随时移除。'),

          SizedBox(height: 12.w),

          // ── 音源列表 ──
          if (sources.isEmpty)
            _EmptyState(onImport: _showImportFromUrl)
          else
            ...sources.map(
              (source) => _SourceCard(
                source: source,
                onToggle: () =>
                    ref.read(sourceListProvider.notifier).toggle(source.id),
                onRemove: source.origin == SourceOrigin.builtin
                    ? null
                    : () => _confirmRemove(source),
              ),
            ),

          SizedBox(height: 32.w),

          // ── 导入区域 ──
          _SectionHeader(
            title: '导入音源',
            subtitle: '支持粘贴 LX Music 格式的源脚本或输入 .js 文件URL',
          ),

          SizedBox(height: 12.w),

          // 导入按钮
          Row(
            children: [
              Expanded(
                child: _ImportButton(
                  icon: Icons.link,
                  label: '从URL导入',
                  onTap: _showImportFromUrl,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _ImportButton(
                  icon: Icons.code,
                  label: '粘贴脚本',
                  onTap: _showImportDialog,
                ),
              ),
            ],
          ),

          SizedBox(height: 80.w),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.w,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.w,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.w,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20.w),
              Text(
                '粘贴源脚本',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.w),
              Text(
                '粘贴 LX Music 格式的 .js 源脚本内容',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
              ),
              SizedBox(height: 16.w),
              TextField(
                controller: controller,
                maxLines: 5,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.sp,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: '粘贴脚本内容...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.textTertiary),
                  ),
                ),
              ),
              SizedBox(height: 16.w),
              SizedBox(
                width: double.infinity,
                height: 48.w,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () async {
                    final script = controller.text.trim();
                    if (script.isEmpty) return;
                    Navigator.pop(ctx);

                    _showLoading('正在验证脚本...');
                    final result = await ref
                        .read(sourceListProvider.notifier)
                        .importScript(script);
                    Navigator.pop(context); // dismiss loading

                    if (result.success) {
                      _showSnackBar('导入成功: ${result.source!.name}');
                    } else {
                      _showError(result.error ?? '导入失败');
                    }
                  },
                  child: Text(
                    '导入',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImportFromUrl() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.w,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.w,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.w,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20.w),
              Text(
                '从URL导入',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.w),
              Text(
                '输入 LX Music 源脚本的 .js 文件URL',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
              ),
              SizedBox(height: 16.w),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://example.com/source.js',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.textTertiary),
                  ),
                ),
              ),
              SizedBox(height: 16.w),
              SizedBox(
                width: double.infinity,
                height: 48.w,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () async {
                    final url = controller.text.trim();
                    if (url.isEmpty) return;
                    Navigator.pop(ctx);

                    _showLoading('正在下载脚本...');
                    final result = await ref
                        .read(sourceListProvider.notifier)
                        .importFromUrl(url);
                    Navigator.pop(context);

                    if (result.success) {
                      _showSnackBar('导入成功: ${result.source!.name}');
                    } else {
                      _showError(result.error ?? '导入失败');
                    }
                  },
                  child: Text(
                    '下载并导入',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmRemove(SourceDefinition source) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          '移除音源',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '确定要移除「${source.name}」吗？',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(sourceListProvider.notifier).remove(source.id);
              Navigator.pop(ctx);
            },
            child: const Text('移除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showLoading(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: GlassPanel(
          blur: 16,
          borderRadius: 24,
          tintColor: AppColors.surfaceDark,
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16.w),
                Text(
                  msg,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('导入失败', style: TextStyle(color: AppColors.error)),
        content: Text(
          msg,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ── 子组件 ──

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.w),
        Text(
          subtitle,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  final SourceDefinition source;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;

  const _SourceCard({
    required this.source,
    required this.onToggle,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = source.enabled;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.w),
      child: GlassPanel(
        blur: 10,
        borderRadius: 14,
        tintColor: enabled
            ? AppColors.surfaceLight
            : AppColors.surfaceLight.withValues(alpha: 0.3),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 状态图标
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.textTertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      enabled ? Icons.music_note : Icons.music_note_outlined,
                      color: enabled
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      size: 22.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                source.name,
                                style: TextStyle(
                                  color: enabled
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.w),
                        Text(
                          _buildSubtitle(),
                          style: TextStyle(
                            color: enabled
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 开关
                  Switch(
                    value: enabled,
                    onChanged: (_) => onToggle(),
                    activeTrackColor: AppColors.primary,
                  ),
                ],
              ),

              // 能力标签
              if (source.capabilities.isNotEmpty && enabled) ...[
                SizedBox(height: 10.w),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.w,
                  children: [
                    for (final cap in source.capabilities.values)
                      _CapabilityChip(capability: cap),
                  ],
                ),
              ],

              // 操作按钮
              if (onRemove != null) ...[
                SizedBox(height: 8.w),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16.sp,
                      color: AppColors.error,
                    ),
                    label: Text(
                      '移除',
                      style: TextStyle(color: AppColors.error, fontSize: 13.sp),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (source.origin == SourceOrigin.builtin) parts.add('内置');
    if (source.version != null) parts.add('v${source.version}');
    if (source.author != null) parts.add(source.author!);
    if (source.description != null && source.description!.isNotEmpty) {
      parts.add(source.description!);
    }
    if (parts.isEmpty) {
      parts.add(
        source.capabilities.isNotEmpty
            ? '${source.capabilities.length} 个子源'
            : '等待初始化...',
      );
    }
    return parts.join(' · ');
  }
}

class _CapabilityChip extends StatelessWidget {
  final SourceCapability capability;

  const _CapabilityChip({required this.capability});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${capability.name} (${capability.actions.join('/')})',
        style: TextStyle(color: AppColors.primary, fontSize: 11.sp),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;

  const _EmptyState({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: 12,
      borderRadius: 14,
      tintColor: AppColors.surfaceLight,
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 48.sp,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: 12.w),
            Text(
              '还没有任何音源',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15.sp),
            ),
            SizedBox(height: 4.w),
            Text(
              '导入音源后即可搜索和播放音乐',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13.sp),
            ),
            SizedBox(height: 16.w),
            ElevatedButton.icon(
              onPressed: onImport,
              icon: Icon(Icons.add, size: 18.sp),
              label: const Text('导入音源'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImportButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: GlassPanel(
          blur: 10,
          borderRadius: 14,
          tintColor: AppColors.surfaceLight,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.w),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 28.sp),
                SizedBox(height: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
