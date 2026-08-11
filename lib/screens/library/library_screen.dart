import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/account_playlists_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/player_provider.dart';
import '../../music_source/models/music_list.dart';
import '../../widgets/album_art.dart';

/// 音乐库 — Apple Music 风格
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistProvider);
    final accountPlaylists = ref.watch(accountPlaylistsProvider);
    final favoritesState = ref.watch(favoritesProvider);
    final recentPlayed = favoritesState.recentlyPlayed;
    final favorites = favoritesState.favorites;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 大标题 + 右上操作按钮
        SliverToBoxAdapter(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: (_scrollOffset < 60) ? 1.0 : 0.0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppSizes.paddingH, 60.w, AppSizes.paddingH, 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '音乐库',
                    style: TextStyle(
                      fontSize: 34.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassPanel(
                        blur: 8,
                        circle: true,
                        tintColor: AppColors.surfaceLight,
                        child: IconButton(
                          icon: Icon(Icons.settings_rounded, color: AppColors.textSecondary, size: 20.sp),
                          onPressed: () => context.push('/settings'),
                          padding: EdgeInsets.all(8.w),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GlassPanel(
                        blur: 8,
                        circle: true,
                        tintColor: AppColors.surfaceLight,
                        child: IconButton(
                          icon: Icon(Icons.add_rounded, color: AppColors.primary, size: 20.sp),
                          onPressed: _showCreatePlaylistDialog,
                          padding: EdgeInsets.all(8.w),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 问候语
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSizes.paddingH, 0, AppSizes.paddingH, 24.w),
            child: Text(
              _getGreeting(),
              style: TextStyle(fontSize: 15.sp, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ),

        // 收藏 Hero 卡片
        if (favorites.isNotEmpty)
          SliverToBoxAdapter(child: _buildFavoritesHero(favorites)),

        // 最近播放 — 横向滚动
        if (recentPlayed.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildSectionHeader('最近播放')),
          SliverToBoxAdapter(child: _buildHorizontalSongList(recentPlayed.take(15).toList(), recentPlayed)),
        ],

        // 歌单区：登录平台「我喜欢的音乐」（按平台分组） + 本地自建歌单
        if (playlists.isNotEmpty || accountPlaylists.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildSectionHeader('我的歌单', count: _playlistTotalCount(playlists, accountPlaylists))),
          // 各登录平台的「我喜欢的音乐」（未登录平台不会出现在 accountPlaylists）
          for (final group in accountPlaylists) ...[
            SliverToBoxAdapter(child: _buildPlaylistGroupHeader(group.sourceName)),
            SliverToBoxAdapter(
              child: _buildPlaylistGrid(const [], group.lists,
                  platformName: group.sourceName),
            ),
          ],
          // 本地自建歌单
          if (playlists.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildPlaylistGroupHeader('本地歌单')),
            SliverToBoxAdapter(child: _buildPlaylistGrid(playlists, const [])),
          ],
        ],

        // 空状态
        if (recentPlayed.isEmpty && favorites.isEmpty && playlists.isEmpty && accountPlaylists.isEmpty)
          _buildEmptyState(),

        SliverToBoxAdapter(child: SizedBox(height: 140.w)),
      ],
    );
  }

  // ──── 空状态 ────
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headphones_rounded, size: 72.sp, color: AppColors.textTertiary.withValues(alpha: 0.35)),
            SizedBox(height: 20.w),
            Text(
              '欢迎使用 All Music',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            SizedBox(height: 10.w),
            Text(
              '导入音源后即可搜索和播放音乐',
              style: TextStyle(fontSize: 15.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 28.w),
            GlassPanel(
              blur: 12,
              borderRadius: 20,
              tintColor: AppColors.primary.withValues(alpha: 0.25),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.w),
                child: GestureDetector(
                  onTap: () => context.push('/settings'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_link_rounded, color: AppColors.primary, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text('导入音源', style: TextStyle(color: AppColors.primary, fontSize: 16.sp, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──── 收藏 Hero 卡片 ────
  Widget _buildFavoritesHero(List<Song> favorites) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.paddingH, 0, AppSizes.paddingH, 12.w),
      child: GestureDetector(
        onTap: () => context.push('/favorites'),
        child: Hero(
          tag: 'favorites_card',
          child: Material(
            color: Colors.transparent,
            child: GlassPanel(
              blur: 16,
              borderRadius: 24,
              tintColor: AppColors.primary.withValues(alpha: 0.12),
              child: Container(
                height: 150.w,
                padding: EdgeInsets.all(20.w),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10.w,
                      top: -10.w,
                      bottom: -10.w,
                      width: 160.w,
                      child: _buildFavoritesCollage(favorites),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.w),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '精选',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '我的收藏',
                              style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.5),
                            ),
                            SizedBox(height: 4.w),
                            Text(
                              '${favorites.length} 首精选歌曲',
                              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesCollage(List<Song> songs) {
    final displayed = songs.take(4).toList();
    return Stack(
      children: List.generate(displayed.length, (i) {
        final size = 100.0.w - i * 12.w;
        final offset = 8.0.w + i * 16.w;
        return Positioned(
          right: offset,
          bottom: offset,
          child: Transform.rotate(
            angle: (i - 1.5) * 0.12,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(-4, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AlbumArt(coverUrl: displayed[i].albumCover, size: size, borderRadius: 14),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ──── 横向滚动歌曲卡片 ────
  Widget _buildHorizontalSongList(List<Song> songs, List<Song> fullQueue) {
    final currentSong = ref.watch(playerProvider.select((s) => s.currentSong));

    return SizedBox(
      height: 190.w,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH - 8.w),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final isPlaying = currentSong?.dedupeKey == song.dedupeKey;

          return GestureDetector(
            behavior: HitTestBehavior.opaque, // 整卡任意位置可点
            onTap: () => ref.read(playerProvider.notifier).playPlaylist(fullQueue.toList(), startIndex: index),
            child: Container(
              width: 140.w,
              margin: EdgeInsets.symmetric(horizontal: 8.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      GlassPanel(
                        blur: 10,
                        borderRadius: 14,
                        tintColor: AppColors.surfaceLight,
                        child: AlbumArt(coverUrl: song.albumCover, size: 140.w, isPlaying: isPlaying, borderRadius: 14),
                      ),
                      if (isPlaying)
                        Positioned(
                          right: 8.w,
                          bottom: 8.w,
                          child: Container(
                            width: 32.w,
                            height: 32.w,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 12)],
                            ),
                            child: Icon(Icons.equalizer_rounded, color: Colors.white, size: 18.sp),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8.w),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Text(
                      song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: isPlaying ? AppColors.primary : AppColors.textPrimary),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ──── 歌单数量（平台歌单 + 本地歌单）────
  int _playlistTotalCount(
      List<Playlist> playlists, List<PlatformPlaylistGroup> groups) {
    return playlists.length +
        groups.fold(0, (sum, g) => sum + g.lists.length);
  }

  // ──── 平台分组小标题 ────
  Widget _buildPlaylistGroupHeader(String name) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(AppSizes.paddingH, 10.w, AppSizes.paddingH, 2.w),
      child: Row(
        children: [
          Container(
            width: 3.w,
            height: 14.w,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            name,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ──── 歌单网格（平台「我喜欢的音乐」在前，本地自建歌单在后）────
  Widget _buildPlaylistGrid(
    List<Playlist> playlists,
    List<MusicListInfo> accountPlaylists, {
    String? platformName,
  }) {
    final width =
        (MediaQuery.of(context).size.width - AppSizes.paddingH * 2 - 12.w) / 2;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 12.w,
        children: [
          // 平台「我喜欢的音乐」卡片
          for (final info in accountPlaylists)
            _buildAccountPlaylistCard(info, width,
                platformName: platformName),
          // 本地自建歌单卡片
          for (final pl in playlists) _buildLocalPlaylistCard(pl, width),
        ],
      ),
    );
  }

  /// 平台「我喜欢的音乐」卡片 → 平台歌单详情（list-detail）
  Widget _buildAccountPlaylistCard(MusicListInfo info, double width,
      {String? platformName}) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: () => context.push('/list-detail', extra: info),
        child: GlassPanel(
          blur: 10,
          borderRadius: 20,
          tintColor: AppColors.surfaceLight,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 120.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accentPurple.withValues(alpha: 0.3),
                        AppColors.accentBlue.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (info.picUrl != null && info.picUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            info.picUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.favorite_rounded,
                                  color: AppColors.textSecondary, size: 40.sp),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Icon(Icons.favorite_rounded,
                              color: AppColors.textSecondary, size: 40.sp),
                        ),
                      // 平台标注徽标
                      if (platformName != null)
                        Positioned(
                          left: 8.w,
                          top: 8.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.w, vertical: 2.w),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              platformName,
                              style: TextStyle(
                                  fontSize: 10.sp, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 10.w),
                Text(
                  info.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                SizedBox(height: 2.w),
                Text(
                  info.countText,
                  style: TextStyle(
                      fontSize: 12.sp, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 本地自建歌单卡片 → 本地歌单详情（/playlist/:id）
  Widget _buildLocalPlaylistCard(Playlist pl, double width) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: () => context.push('/playlist/${pl.id}'),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showPlaylistActions(pl);
        },
        child: GlassPanel(
          blur: 10,
          borderRadius: 20,
          tintColor: AppColors.surfaceLight,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 120.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.3),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Center(
                      child: Icon(Icons.queue_music_rounded,
                          color: AppColors.textSecondary, size: 40.sp)),
                ),
                SizedBox(height: 10.w),
                Text(
                  pl.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                SizedBox(height: 2.w),
                Text(
                  '${pl.songCount} 首歌曲',
                  style: TextStyle(
                      fontSize: 12.sp, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──── 通用组件 ────
  Widget _buildSectionHeader(String title, {int? count}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.paddingH, 28.w, AppSizes.paddingH, 12.w),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.3),
          ),
          if (count != null) ...[
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surfaceLight,
              ),
              child: Text('$count', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深人静，来点温柔的旋律伴你入眠';
    if (hour < 12) return '早上好 ☀️ 用音乐点亮新的一天';
    if (hour < 18) return '午后时光，让节奏律动起来';
    return '晚上好 🌙 放松心情，享受音乐';
  }

  // ──── 歌单操作 ────
  void _showPlaylistActions(Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36.w, height: 4.w, margin: EdgeInsets.only(top: 8.w, bottom: 16.w), decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Container(width: 40.w, height: 40.w, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.primary.withValues(alpha: 0.15)), child: Icon(Icons.queue_music_rounded, color: AppColors.primary, size: 20.sp)),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(playlist.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('${playlist.songCount} 首', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.w),
              Divider(color: AppColors.textTertiary.withValues(alpha: 0.2), height: 1),
              ListTile(
                leading: Icon(Icons.edit_rounded, color: AppColors.textPrimary, size: 22.sp),
                title: Text('重命名', style: TextStyle(color: AppColors.textPrimary, fontSize: 15.sp)),
                onTap: () { Navigator.pop(context); _showRenameDialog(playlist); },
              ),
              if (playlist.songs.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.play_arrow_rounded, color: AppColors.textPrimary, size: 22.sp),
                  title: Text('播放全部', style: TextStyle(color: AppColors.textPrimary, fontSize: 15.sp)),
                  onTap: () { Navigator.pop(context); ref.read(playerProvider.notifier).playPlaylist(playlist.songs); },
                ),
              ListTile(
                leading: Icon(Icons.delete_rounded, color: Colors.red, size: 22.sp),
                title: Text('删除歌单', style: TextStyle(color: Colors.red, fontSize: 15.sp)),
                onTap: () { Navigator.pop(context); _confirmDeletePlaylist(playlist); },
              ),
              SizedBox(height: 8.w),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassPanel(
          blur: 20, borderRadius: 24, tintColor: AppColors.surfaceDark,
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('重命名歌单', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                SizedBox(height: 20.w),
                GlassPanel(
                  blur: 8, borderRadius: 12, tintColor: AppColors.surfaceLight,
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '输入新名称', hintStyle: TextStyle(color: AppColors.textTertiary),
                      border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
                    ),
                  ),
                ),
                SizedBox(height: 24.w),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.textSecondary))),
                  SizedBox(width: 12.w),
                  GlassPanel(blur: 10, borderRadius: 12, tintColor: AppColors.primary.withValues(alpha: 0.3),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.w),
                      child: GestureDetector(
                        onTap: () { if (controller.text.trim().isNotEmpty) { ref.read(playlistProvider.notifier).renamePlaylist(playlist.id, controller.text.trim()); Navigator.pop(context); } },
                        child: const Text('确认', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeletePlaylist(Playlist playlist) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassPanel(
          blur: 20, borderRadius: 24, tintColor: AppColors.surfaceDark,
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('删除歌单', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                SizedBox(height: 12.w),
                Text('确定要删除「${playlist.name}」吗？此操作不可恢复。', textAlign: TextAlign.center, style: TextStyle(fontSize: 15.sp, color: AppColors.textSecondary)),
                SizedBox(height: 24.w),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.textSecondary))),
                  SizedBox(width: 12.w),
                  GlassPanel(blur: 10, borderRadius: 12, tintColor: Colors.red.withValues(alpha: 0.3),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.w),
                      child: GestureDetector(
                        onTap: () { ref.read(playlistProvider.notifier).deletePlaylist(playlist.id); Navigator.pop(context); },
                        child: const Text('删除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassPanel(
          blur: 20, borderRadius: 24, tintColor: AppColors.surfaceDark,
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('创建歌单', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                SizedBox(height: 20.w),
                GlassPanel(
                  blur: 8, borderRadius: 12, tintColor: AppColors.surfaceLight,
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(hintText: '输入歌单名称', hintStyle: TextStyle(color: AppColors.textTertiary), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w)),
                  ),
                ),
                SizedBox(height: 24.w),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.textSecondary))),
                  SizedBox(width: 12.w),
                  GlassPanel(blur: 10, borderRadius: 12, tintColor: AppColors.primary.withValues(alpha: 0.3),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.w),
                      child: GestureDetector(
                        onTap: () { if (controller.text.trim().isNotEmpty) { ref.read(playlistProvider.notifier).createPlaylist(controller.text.trim()); Navigator.pop(context); } },
                        child: const Text('创建', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


