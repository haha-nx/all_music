import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'account_center_screen.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../providers/settings_provider.dart';
import '../../music_source/models/music_track.dart';
import '../../music_source/providers/music_source_provider.dart';

/// 设置页 — 音源管理 + 关于
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceListProvider);

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

        // 音源中心（新版）
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
                    icon: Icons.hub_outlined,
                    title: '音源中心（新版）',
                    subtitle: '管理音源、导入脚本、测试引擎',
                    onTap: () {
                      context.push('/source-hub');
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.science_outlined,
                    title: '音源测试工具',
                    subtitle: '验证搜索、播放、歌词功能',
                    onTap: () {
                      context.push('/source-test');
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.account_circle_outlined,
                    title: '账号中心',
                    subtitle: '登录内置音源账号（网易云/QQ音乐等）',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountCenterScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // 已导入的音源列表
        if (sources.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildSectionTitle('已导入音源'),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final source = sources[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingH,
                    vertical: 4,
                  ),
                  child: GlassPanel(
                    blur: 8,
                    borderRadius: 12,
                    tintColor: source.enabled
                        ? AppColors.primary.withValues(alpha: 0.05)
                        : AppColors.surfaceLight,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: source.enabled
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.textTertiary.withValues(alpha: 0.1),
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: source.enabled ? AppColors.primary : AppColors.textTertiary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        source.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: source.enabled ? AppColors.textPrimary : AppColors.textTertiary,
                        ),
                      ),
                      subtitle: Text(
                        source.description ?? (source.enabled ? '已启用' : '已禁用'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                      trailing: Switch(
                        value: source.enabled,
                        onChanged: (_) {
                          ref.read(sourceListProvider.notifier).toggle(source.id);
                        },
                        activeThumbColor: AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
              childCount: sources.length,
            ),
          ),
        ],
      SliverToBoxAdapter(
        child: _buildSectionTitle('播放与下载'),
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
                // 默认音质
                InkWell(
                  onTap: () => _showQualityPicker(context, ref),
                  borderRadius: BorderRadius.circular(AppSizes.cardBorderRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.high_quality_rounded,
                            color: AppColors.primary, size: 24),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '默认音质',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '播放与下载时优先请求的音质',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _qualityLabel(
                              ref.watch(settingsProvider).defaultQuality),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textTertiary, size: 20),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.surfaceDark),
                _buildMenuItem(
                  icon: Icons.download_rounded,
                  title: '下载管理',
                  subtitle: '查看和管理下载任务',
                  onTap: () => context.push('/downloads'),
                ),
              ],
            ),
          ),
        ),
      ),
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
                  subtitle: '2.0.0',
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

  /// 音质值 → 显示标签
  String _qualityLabel(String q) {
    for (final quality in MusicQuality.values) {
      if (quality.value == q) return quality.label;
    }
    return q;
  }

  /// 默认音质选择面板
  void _showQualityPicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).defaultQuality;
    final options = [
      MusicQuality.lq,
      MusicQuality.hq,
      MusicQuality.flac,
      MusicQuality.flac24bit,
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GlassPanel(
        blur: 20,
        borderRadius: 20,
        tintColor: AppColors.surfaceDark,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '默认音质',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              for (final quality in options)
                ListTile(
                  dense: true,
                  title: Text(
                    quality.label,
                    style: TextStyle(
                      fontSize: 15,
                      color: quality.value == current
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: quality.value == current
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(settingsProvider.notifier)
                        .setDefaultQuality(quality.value);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
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
