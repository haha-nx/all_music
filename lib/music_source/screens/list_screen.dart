import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants.dart';
import '../../../providers/list_provider.dart';
import '../../../widgets/glass_panel.dart';
import '../../../widgets/liquid_bottom_bar.dart';
import '../models/music_list.dart';

/// 排行榜 — 聚合所有启用音源的榜单（lx-music list 动作）
class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key});

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen> {
  @override
  void initState() {
    super.initState();
    // 延迟一帧触发刷新，避免 initState 中的异步 setState 警告
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶栏
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12.w,
                    8.w,
                    AppSizes.paddingH,
                    8.w,
                  ),
                  child: Row(
                    children: [
                      GlassPanel(
                        blur: 8,
                        circle: true,
                        tintColor: AppColors.surfaceLight,
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary,
                            size: 18.sp,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '排行榜',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      GlassPanel(
                        blur: 8,
                        circle: true,
                        tintColor: AppColors.surfaceLight,
                        child: IconButton(
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: AppColors.textPrimary,
                            size: 18.sp,
                          ),
                          onPressed: () =>
                              ref.read(listsProvider.notifier).refresh(),
                        ),
                      ),
                    ],
                  ),
                ),

                // 状态区
                if (state.isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (state.error != null && state.isEmpty)
                  Expanded(
                    child: _ErrorState(
                      error: state.error!,
                      onRetry: () => ref.read(listsProvider.notifier).refresh(),
                    ),
                  )
                else if (state.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        '暂无榜单数据\n请导入支持 list 动作的标准 LX 音源',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surfaceDark,
                      onRefresh: () =>
                          ref.read(listsProvider.notifier).refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(bottom: 120.w),
                        children: [
                          for (final section in state.sections) ...[
                            _buildSectionHeader(
                              section.sourceName,
                            ),
                            _buildListGrid(section.lists),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // 底部播放胶囊（无歌曲时自动隐藏）
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PlayerCapsuleBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String name) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.paddingH,
        14.w,
        AppSizes.paddingH,
        10.w,
      ),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.w,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            name,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 榜单两列网格（上下滑动）
  Widget _buildListGrid(List<MusicListInfo> lists) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10.w,
        crossAxisSpacing: 16.w,
        childAspectRatio: 0.8,
      ),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        final info = lists[index];
        return _ListCard(
          info: info,
          onTap: () => context.push('/list-detail', extra: info),
        );
      },
    );
  }
}

class _ListCard extends StatelessWidget {
  final MusicListInfo info;
  final VoidCallback onTap;

  const _ListCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 整卡任意位置可点
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            blur: 10,
            borderRadius: 20,
            tintColor: AppColors.surfaceLight,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: info.picUrl != null && info.picUrl!.isNotEmpty
                    ? Image.network(
                        info.picUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _coverPlaceholder(),
                      )
                    : _coverPlaceholder(),
              ),
            ),
          ),
          SizedBox(height: 6.w),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              info.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
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
      child: Center(
        child: Icon(
          Icons.leaderboard_rounded,
          color: AppColors.textSecondary,
          size: 36.sp,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 56.sp,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: 16.w),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 20.w),
          GlassPanel(
            blur: 10,
            borderRadius: 20,
            tintColor: AppColors.primary.withValues(alpha: 0.2),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.w),
              child: GestureDetector(
                onTap: onRetry,
                child: const Text(
                  '重试',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
