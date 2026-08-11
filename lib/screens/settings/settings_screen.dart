import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'account_center_screen.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_version.dart';
import '../../music_source/models/music_track.dart';

/// 设置页 — 音源管理 + 关于
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
        // 返回按钮
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.w, 52.w, 0, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GlassPanel(
                blur: 8,
                borderRadius: 24,
                tintColor: AppColors.surfaceLight,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                    size: 18.sp,
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
            padding: EdgeInsets.fromLTRB(
              AppSizes.paddingH,
              12.w,
              AppSizes.paddingH,
              24.w,
            ),
            child: Text(
              '设置',
              style: TextStyle(
                fontSize: 34.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),


        // 音源账号：账号中心（音源中心入口已隐藏）
        SliverToBoxAdapter(
          child: _buildSectionTitle('账号'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
            child: GlassPanel(
              blur: 12,
              borderRadius: AppSizes.cardBorderRadius,
              tintColor: AppColors.surfaceLight,
              child: Column(
                children: [
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
      SliverToBoxAdapter(
        child: _buildSectionTitle('播放与下载'),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
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
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.w),
                    child: Row(
                      children: [
                        Icon(Icons.high_quality_rounded,
                            color: AppColors.primary, size: 24.sp),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '默认音质',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2.w),
                              Text(
                                '播放与下载时优先请求的音质',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _qualityLabel(
                              ref.watch(settingsProvider).defaultQuality),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textTertiary, size: 20.sp),
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
          padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
          child: GlassPanel(
            blur: 12,
            borderRadius: AppSizes.cardBorderRadius,
            tintColor: AppColors.surfaceLight,
            child: Column(
              children: [
                FutureBuilder<String>(
                  future: AppVersion.get(),
                  builder: (context, snapshot) => _buildMenuItem(
                    icon: Icons.info_outline_rounded,
                    title: '版本',
                    subtitle: snapshot.data ?? '1.0.0',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: 120.w)),
      ],
      ),
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.paddingH,
        24.w,
        AppSizes.paddingH,
        12.w,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
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
        borderRadius: 24,
        tintColor: AppColors.surfaceDark,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  '默认音质',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              for (final quality in options)
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(
                    quality.label,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: quality.value == current
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: quality.value == current
                      ? Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 20.sp)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(settingsProvider.notifier)
                        .setDefaultQuality(quality.value);
                  },
                ),
              SizedBox(height: 16.w),
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.w),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24.sp),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 22.sp),
          ],
        ),
      ),
    );
  }

}
