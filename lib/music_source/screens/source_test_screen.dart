import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../widgets/glass_panel.dart';
import '../core/music_backend.dart';
import '../models/music_track.dart';
import '../providers/music_source_provider.dart';

/// 音源测试页面
///
/// 用于验证音源引擎的搜索、播放URL、歌词获取功能。
class SourceTestScreen extends ConsumerStatefulWidget {
  const SourceTestScreen({super.key});

  @override
  ConsumerState<SourceTestScreen> createState() => _SourceTestScreenState();
}

class _SourceTestScreenState extends ConsumerState<SourceTestScreen> {
  final _keywordController = TextEditingController(text: '周杰伦');
  MusicBackend? _bridge;
  String? _activeSourceId;
  bool _loading = false;
  String _status = '等待测试...';
  List<MusicTrack> _results = [];
  String? _playUrl;
  String? _lyricPreview;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    setState(() => _status = '正在初始化音源...');

    final notifier = ref.read(sourceListProvider.notifier);
    final enabled = notifier.manager.sources.where((s) => s.enabled).toList();
    if (enabled.isEmpty) {
      setState(() {
        _status = '还没有可用音源，请先到音源中心导入音源';
      });
      return;
    }

    // 依次尝试启用的音源，取第一个初始化成功的
    for (final source in enabled) {
      final backend = await notifier.getBackend(source.id);
      if (backend != null && backend.ready) {
        _bridge = backend;
        _activeSourceId = source.id;
        break;
      }
    }

    setState(() {
      if (_bridge != null && _bridge!.ready) {
        _status = '后端就绪 ✅\n'
            '源: $_activeSourceId\n'
            '子源: ${_bridge!.capabilities.keys.join(", ")}\n'
            '搜索源: ${_bridge!.searchKeys.join(", ")}';
      } else {
        _status = '后端初始化失败 ❌\n${_bridge?.lastError ?? "未知错误"}';
      }
    });
  }

  Future<void> _testSearch() async {
    if (_bridge == null || !_bridge!.ready) {
      setState(() => _status = '引擎未就绪');
      return;
    }

    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _loading = true;
      _results = [];
      _playUrl = null;
      _lyricPreview = null;
      _status = '搜索中: $keyword...';
    });

    try {
      final results = await _bridge!.search(keyword, limit: 10);
      setState(() {
        _loading = false;
        _results = results;
        _status = '搜索完成: 找到 ${results.length} 条结果';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = '搜索失败: $e';
      });
    }
  }

  Future<void> _testGetUrl(MusicTrack track) async {
    if (_bridge == null) return;

    setState(() {
      _status = '获取播放URL: ${track.title}...';
      _playUrl = null;
    });

    try {
      final url = await _bridge!.getMusicUrl(track);
      setState(() {
        if (url != null && url.isNotEmpty) {
          _playUrl = url;
          _status = '获取播放URL成功 ✅';
        } else {
          _status = '获取播放URL失败: 返回空';
        }
      });
    } catch (e) {
      setState(() => _status = '获取播放URL异常: $e');
    }
  }

  Future<void> _testGetLyric(MusicTrack track) async {
    if (_bridge == null) return;

    setState(() {
      _status = '获取歌词: ${track.title}...';
      _lyricPreview = null;
    });

    try {
      final lyric = await _bridge!.getLyric(track);
      setState(() {
        if (lyric != null && lyric.isNotEmpty) {
          _lyricPreview = lyric.length > 300 ? '${lyric.substring(0, 300)}...' : lyric;
          _status = '获取歌词成功 ✅ (${lyric.length} 字符)';
        } else {
          _status = '获取歌词失败: 返回空';
        }
      });
    } catch (e) {
      setState(() => _status = '获取歌词异常: $e');
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _bridge?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('音源测试'),
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
          // 状态
          _statusCard(),

          const SizedBox(height: 16),

          // 搜索框
          _searchBar(),

          const SizedBox(height: 20),

          // 搜索结果
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_results.isNotEmpty) ...[
            const Text(
              '搜索结果',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final track in _results) _trackCard(track),
          ],

          // 歌词预览
          if (_lyricPreview != null) ...[
            const SizedBox(height: 20),
            const Text(
              '歌词预览',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            GlassPanel(
              blur: 10,
              borderRadius: 14,
              tintColor: AppColors.surfaceLight,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _lyricPreview!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],

          // 播放URL
          if (_playUrl != null) ...[
            const SizedBox(height: 20),
            const Text(
              '播放URL',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            GlassPanel(
              blur: 10,
              borderRadius: 14,
              tintColor: AppColors.surfaceLight,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _playUrl!,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return GlassPanel(
      blur: 12,
      borderRadius: 14,
      tintColor: _bridge?.ready == true
          ? AppColors.success.withValues(alpha: 0.1)
          : AppColors.error.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _bridge?.ready == true
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: _bridge?.ready == true
                      ? AppColors.success
                      : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '引擎状态',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: GlassPanel(
            blur: 10,
            borderRadius: 14,
            tintColor: AppColors.surfaceLight,
            child: TextField(
              controller: _keywordController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '输入搜索关键词',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onSubmitted: (_) => _testSearch(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
            ),
            onPressed: _loading ? null : _testSearch,
            child: const Text('搜索', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _trackCard(MusicTrack track) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassPanel(
        blur: 8,
        borderRadius: 14,
        tintColor: AppColors.surfaceLight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.textTertiary.withValues(alpha: 0.2),
                  child: track.coverUrl != null && track.coverUrl!.isNotEmpty
                      ? Image.network(
                          track.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, _) =>
                              Icon(Icons.music_note,
                                  color: AppColors.textTertiary, size: 22),
                        )
                      : Icon(Icons.music_note,
                          color: AppColors.textTertiary, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${track.artist} · ${track.album ?? ""} · ${track.sourceKey}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.durationFormatted,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // 操作按钮
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: AppColors.textTertiary, size: 18),
                color: AppColors.surfaceDark,
                onSelected: (action) {
                  if (action == 'url') _testGetUrl(track);
                  if (action == 'lyric') _testGetLyric(track);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'url', child: Text('获取播放URL')),
                  const PopupMenuItem(value: 'lyric', child: Text('获取歌词')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
