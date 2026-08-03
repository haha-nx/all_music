import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/source_provider.dart';
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
    final favoritesState = ref.watch(favoritesProvider);
    final sources = ref.watch(sourceProvider);
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
              padding: const EdgeInsets.fromLTRB(AppSizes.paddingH, 60, AppSizes.paddingH, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '音乐库',
                    style: TextStyle(
                      fontSize: 34,
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
                        borderRadius: 14,
                        tintColor: AppColors.surfaceLight,
                        child: IconButton(
                          icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary, size: 20),
                          onPressed: () => context.push('/settings'),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GlassPanel(
                        blur: 8,
                        borderRadius: 14,
                        tintColor: AppColors.surfaceLight,
                        child: IconButton(
                          icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                          onPressed: _showCreatePlaylistDialog,
                          padding: const EdgeInsets.all(8),
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
            padding: const EdgeInsets.fromLTRB(AppSizes.paddingH, 0, AppSizes.paddingH, 24),
            child: Text(
              _getGreeting(),
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
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

        // 歌单网格
        if (playlists.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildSectionHeader('我的歌单', count: playlists.length)),
          SliverToBoxAdapter(child: _buildPlaylistGrid(playlists)),
        ],

        // 空状态
        if (recentPlayed.isEmpty && favorites.isEmpty && playlists.isEmpty)
          _buildEmptyState(),

        // 浏览快捷入口
        SliverToBoxAdapter(child: _buildSectionHeader('浏览')),
        SliverToBoxAdapter(child: _buildBrowseSection(sources.length, favorites.length, playlists.length)),

        const SliverToBoxAdapter(child: SizedBox(height: 140)),
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
            Icon(Icons.headphones_rounded, size: 72, color: AppColors.textTertiary.withValues(alpha: 0.35)),
            const SizedBox(height: 20),
            const Text(
              '欢迎使用 All Music',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            const Text(
              '导入音源后即可搜索和播放音乐',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            GlassPanel(
              blur: 12,
              borderRadius: 16,
              tintColor: AppColors.primary.withValues(alpha: 0.25),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                child: GestureDetector(
                  onTap: () => context.push('/settings'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_link_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('导入音源', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.fromLTRB(AppSizes.paddingH, 0, AppSizes.paddingH, 12),
      child: GestureDetector(
        onTap: () => context.push('/favorites'),
        child: Hero(
          tag: 'favorites_card',
          child: Material(
            color: Colors.transparent,
            child: GlassPanel(
              blur: 16,
              borderRadius: 20,
              tintColor: AppColors.primary.withValues(alpha: 0.12),
              child: Container(
                height: 150,
                padding: const EdgeInsets.all(20),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      top: -10,
                      bottom: -10,
                      width: 160,
                      child: _buildFavoritesCollage(favorites),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '精选',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '我的收藏',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${favorites.length} 首精选歌曲',
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
        final size = 100.0 - i * 12;
        final offset = 8.0 + i * 16;
        return Positioned(
          right: offset,
          bottom: offset,
          child: Transform.rotate(
            angle: (i - 1.5) * 0.12,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(-4, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AlbumArt(coverUrl: displayed[i].albumCover, size: size, borderRadius: 12),
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
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH - 8),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final isPlaying = currentSong?.dedupeKey == song.dedupeKey;

          return GestureDetector(
            onTap: () => ref.read(playerProvider.notifier).playPlaylist(fullQueue.toList(), startIndex: index),
            child: Container(
              width: 140,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      GlassPanel(
                        blur: 10,
                        borderRadius: 14,
                        tintColor: AppColors.surfaceLight,
                        child: AlbumArt(coverUrl: song.albumCover, size: 140, isPlaying: isPlaying, borderRadius: 14),
                      ),
                      if (isPlaying)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 12)],
                            ),
                            child: const Icon(Icons.equalizer_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isPlaying ? AppColors.primary : AppColors.textPrimary),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ──── 歌单网格 ────
  Widget _buildPlaylistGrid(List<Playlist> playlists) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: playlists.map((pl) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - AppSizes.paddingH * 2 - 12) / 2,
            child: GestureDetector(
              onTap: () => context.push('/playlist/${pl.id}'),
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showPlaylistActions(pl);
              },
              child: GlassPanel(
                blur: 10,
                borderRadius: 16,
                tintColor: AppColors.surfaceLight,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.3),
                              AppColors.primary.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        child: const Center(child: Icon(Icons.queue_music_rounded, color: AppColors.textSecondary, size: 40)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pl.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pl.songCount} 首歌曲',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ──── 浏览分类 ────
  Widget _buildBrowseSection(int sourceCount, int favCount, int plCount) {
    final items = [
      _BrowseItem('排行榜', Icons.leaderboard_rounded, AppColors.primary, '/lists', '热榜新歌'),
      if (favCount > 0) _BrowseItem('收藏', Icons.favorite_rounded, AppColors.primary, '/favorites', '$favCount 首'),
      if (plCount > 0) _BrowseItem('歌单', Icons.playlist_play_rounded, AppColors.accentPurple, null, '$plCount 个'),
      _BrowseItem('音源', Icons.dns_rounded, AppColors.accentBlue, '/settings', '$sourceCount 个已启用'),
      _BrowseItem('搜索', Icons.search_rounded, AppColors.accentGreen, null, '发现好音乐'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingH),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - AppSizes.paddingH * 2 - 12) / 2,
            child: GestureDetector(
              onTap: () {
                if (item.route != null) {
                  context.push(item.route!);
                } else {
                  // Switch to search tab
                  // Stay - already in library view
                }
              },
              child: GlassPanel(
                blur: 10,
                borderRadius: 16,
                tintColor: item.color.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.color, size: 22),
                      ),
                      const SizedBox(height: 12),
                      Text(item.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text(item.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ──── 通用组件 ────
  Widget _buildSectionHeader(String title, {int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.paddingH, 28, AppSizes.paddingH, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: -0.3),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.surfaceLight,
              ),
              child: Text('$count', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 16), decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.primary.withValues(alpha: 0.15)), child: const Icon(Icons.queue_music_rounded, color: AppColors.primary, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(playlist.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('${playlist.songCount} 首', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: AppColors.textTertiary.withValues(alpha: 0.2), height: 1),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.textPrimary, size: 22),
                title: const Text('重命名', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                onTap: () { Navigator.pop(context); _showRenameDialog(playlist); },
              ),
              if (playlist.songs.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded, color: AppColors.textPrimary, size: 22),
                  title: const Text('播放全部', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                  onTap: () { Navigator.pop(context); ref.read(playerProvider.notifier).playPlaylist(playlist.songs); },
                ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red, size: 22),
                title: const Text('删除歌单', style: TextStyle(color: Colors.red, fontSize: 15)),
                onTap: () { Navigator.pop(context); _confirmDeletePlaylist(playlist); },
              ),
              const SizedBox(height: 8),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('重命名歌单', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                GlassPanel(
                  blur: 8, borderRadius: 12, tintColor: AppColors.surfaceLight,
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: '输入新名称', hintStyle: TextStyle(color: AppColors.textTertiary),
                      border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.textSecondary))),
                  const SizedBox(width: 12),
                  GlassPanel(blur: 10, borderRadius: 12, tintColor: AppColors.primary.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('删除歌单', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Text('确定要删除「${playlist.name}」吗？此操作不可恢复。', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.textSecondary))),
                  const SizedBox(width: 12),
                  GlassPanel(blur: 10, borderRadius: 12, tintColor: Colors.red.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('创建歌单', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                GlassPanel(
                  blur: 8, borderRadius: 12, tintColor: AppColors.surfaceLight,
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(hintText: '输入歌单名称', hintStyle: TextStyle(color: AppColors.textTertiary), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.textSecondary))),
                  const SizedBox(width: 12),
                  GlassPanel(blur: 10, borderRadius: 12, tintColor: AppColors.primary.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

class _BrowseItem {
  final String label;
  final IconData icon;
  final Color color;
  final String? route;
  final String subtitle;
  const _BrowseItem(this.label, this.icon, this.color, this.route, this.subtitle);
}
