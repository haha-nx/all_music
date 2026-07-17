import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../widgets/glass_panel.dart';
import '../models/source_definition.dart';
import '../providers/music_source_provider.dart';

/// 音源管理中心
///
/// 查看、启用/禁用、导入音源。
/// 第一阶段：展示内置六音示例源 + 导入入口。
class SourceHubScreen extends ConsumerStatefulWidget {
  const SourceHubScreen({super.key});

  @override
  ConsumerState<SourceHubScreen> createState() => _SourceHubScreenState();
}

class _SourceHubScreenState extends ConsumerState<SourceHubScreen> {
  @override
  void initState() {
    super.initState();
    // 初始化内置源
    _initBuiltins();
  }

  Future<void> _initBuiltins() async {
    final notifier = ref.read(sourceListProvider.notifier);
    final builtins = await createBuiltinSources();
    if (builtins.isNotEmpty) {
      notifier.manager.initBuiltin(builtins);
    }
  }

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
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingH),
        children: [
          // ── 头部说明 ──
          _SectionHeader(
            title: '已导入音源',
            subtitle: '启用音源后可在搜索中使用。内置音源不可删除。',
          ),

          const SizedBox(height: 12),

          // ── 音源列表 ──
          if (sources.isEmpty)
            _EmptyState(onImport: _showImportDialog)
          else
            ...sources.map((source) => _SourceCard(
                  source: source,
                  onToggle: () =>
                      ref.read(sourceListProvider.notifier).toggle(source.id),
                  onRemove: source.origin == SourceOrigin.user
                      ? () => _confirmRemove(source)
                      : null,
                )),

          const SizedBox(height: 32),

          // ── 导入区域 ──
          _SectionHeader(
            title: '导入音源',
            subtitle: '支持粘贴 LX Music 格式的源脚本或输入 .js 文件URL',
          ),

          const SizedBox(height: 12),

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
              const SizedBox(width: 12),
              Expanded(
                child: _ImportButton(
                  icon: Icons.code,
                  label: '粘贴脚本',
                  onTap: _showImportDialog,
                ),
              ),
            ],
          ),

          const SizedBox(height: 80),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '粘贴源脚本',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '粘贴 LX Music 格式的 .js 源脚本内容',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 5,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: '粘贴脚本内容...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  child: const Text('导入',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '从URL导入',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '输入 LX Music 源脚本的 .js 文件URL',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://example.com/source.js',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  child: const Text('下载并导入',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
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
        title: const Text('移除音源',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '确定要移除「${source.name}」吗？',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(color: AppColors.textSecondary)),
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
          borderRadius: 20,
          tintColor: AppColors.surfaceDark,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(msg,
                    style: const TextStyle(color: AppColors.textSecondary)),
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
        title: const Text('导入失败',
            style: TextStyle(color: AppColors.error)),
        content: Text(msg,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定',
                style: TextStyle(color: AppColors.primary)),
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
    final isBuiltin = source.origin == SourceOrigin.builtin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        blur: 10,
        borderRadius: 14,
        tintColor: enabled
            ? AppColors.surfaceLight
            : AppColors.surfaceLight.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 状态图标
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.textTertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      enabled ? Icons.music_note : Icons.music_note_outlined,
                      color: enabled ? AppColors.primary : AppColors.textTertiary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isBuiltin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentBlue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '内置',
                                  style: TextStyle(
                                    color: AppColors.accentBlue,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _buildSubtitle(),
                          style: TextStyle(
                            color: enabled
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                            fontSize: 12,
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cap in source.capabilities.values)
                      _CapabilityChip(capability: cap),
                  ],
                ),
              ],

              // 操作按钮
              if (onRemove != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.error),
                    label: const Text('移除',
                        style: TextStyle(
                            color: AppColors.error, fontSize: 13)),
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
    if (source.version != null) parts.add('v${source.version}');
    if (source.author != null) parts.add(source.author!);
    if (source.description != null && source.description!.isNotEmpty) {
      parts.add(source.description!);
    }
    if (parts.isEmpty) {
      parts.add(source.capabilities.isNotEmpty
          ? '${source.capabilities.length} 个子源'
          : '等待初始化...');
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${capability.name} (${capability.actions.join('/')})',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
        ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.library_music_outlined,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text(
              '还没有任何音源',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              '导入音源后即可搜索和播放音乐',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('导入音源'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
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
