import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../providers/source_provider.dart';
import '../../providers/favorites_provider.dart';

/// 设置页 — 音源管理 + 关于
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
        // 返回按钮
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 52, 0, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GlassPanel(
                blur: 8,
                borderRadius: 20,
                tintColor: AppColors.surfaceLight,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),
        ),

        // 大标题
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.paddingH,
              12,
              AppSizes.paddingH,
              24,
            ),
            child: Text(
              '设置',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        // 音源管理
        SliverToBoxAdapter(
          child: _buildSectionTitle('音源管理'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
            child: GlassPanel(
              blur: 12,
              borderRadius: AppSizes.cardBorderRadius,
              tintColor: AppColors.surfaceLight,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.source,
                    title: '已导入音源',
                    subtitle: '${sources.length} 个音源',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const _SourceManagePage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // 收藏与历史
        SliverToBoxAdapter(
          child: _buildSectionTitle('数据'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
            child: GlassPanel(
              blur: 12,
              borderRadius: AppSizes.cardBorderRadius,
              tintColor: AppColors.surfaceLight,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.favorite_rounded,
                    title: '收藏歌曲',
                    subtitle: '${favorites.favorites.length} 首',
                  ),
                  _buildMenuItem(
                    icon: Icons.history_rounded,
                    title: '最近播放',
                    subtitle: '${favorites.recentlyPlayed.length} 首',
                    onTap: () {
                      ref.read(favoritesProvider.notifier).clearRecent();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // 关于
        SliverToBoxAdapter(
          child: _buildSectionTitle('关于'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
            child: GlassPanel(
              blur: 12,
              borderRadius: AppSizes.cardBorderRadius,
              tintColor: AppColors.surfaceLight,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.info_outline_rounded,
                    title: '版本',
                    subtitle: '1.0.0',
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingH,
        24,
        AppSizes.paddingH,
        12,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 22),
          ],
        ),
      ),
    );
  }
}

/// 音源管理子页面
class _SourceManagePage extends ConsumerWidget {
  const _SourceManagePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '音源管理',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: () => _showImportDialog(context, ref),
          ),
        ],
      ),
      body: sources.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.source_rounded,
                    size: 80,
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '还没有导入音源',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右上角 + 导入音乐源',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSizes.paddingH),
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassPanel(
                    blur: 10,
                    borderRadius: 16,
                    tintColor: source.enabled
                        ? AppColors.surfaceLight
                        : AppColors.textTertiary.withValues(alpha: 0.05),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: source.enabled
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.textTertiary.withValues(alpha: 0.1),
                        ),
                        child: Icon(
                          Icons.source_rounded,
                          color: source.enabled ? AppColors.primary : AppColors.textTertiary,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        source.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: source.enabled ? AppColors.textPrimary : AppColors.textTertiary,
                        ),
                      ),
                      subtitle: Text(
                        source.apiUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: source.enabled,
                            onChanged: (_) {
                              ref.read(sourceProvider.notifier).toggleEnabled(source.id);
                            },
                            activeThumbColor: AppColors.primary,
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: AppColors.textTertiary, size: 20),
                            color: AppColors.surfaceDark,
                            onSelected: (value) {
                              if (value == 'delete') {
                                ref.read(sourceProvider.notifier).removeSource(source.id);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('删除', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    var isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassPanel(
            blur: 20,
            borderRadius: 24,
            tintColor: AppColors.surfaceDark,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '导入音源',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '支持 URL 导入或直接粘贴',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _GlassInput(
                    controller: nameController,
                    hint: '音源名称',
                  ),
                  const SizedBox(height: 12),
                  _GlassInput(
                    controller: urlController,
                    hint: '音源地址 (URL)',
                  ),
                  // 错误提示
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMsg!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isLoading ? null : () => Navigator.pop(ctx),
                        child: Text(
                          '取消',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GlassPanel(
                        blur: 10,
                        borderRadius: 12,
                        tintColor: AppColors.primary.withValues(alpha: 0.3),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: GestureDetector(
                            onTap: isLoading
                                ? null
                                : () async {
                              final name = nameController.text.trim();
                              final url = urlController.text.trim();
                              if (name.isEmpty || url.isEmpty) return;

                              setDialogState(() {
                                isLoading = true;
                                errorMsg = null;
                              });

                              final result = await ref
                                  .read(sourceProvider.notifier)
                                  .importFromUrl(name, url);

                              if (!ctx.mounted) return;

                              if (result.success) {
                                Navigator.pop(ctx);
                              } else {
                                setDialogState(() {
                                  isLoading = false;
                                  errorMsg = result.error;
                                });
                              }
                            },
                            child: isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '导入',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 玻璃输入框组件
class _GlassInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _GlassInput({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: 8,
      borderRadius: 12,
      tintColor: AppColors.surfaceLight,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
