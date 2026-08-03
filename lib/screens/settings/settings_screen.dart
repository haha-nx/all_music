import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/glass_panel.dart';
import '../../config/constants.dart';
import '../../providers/source_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/music_source.dart';
import '../../music_source/models/music_track.dart';

/// 设置页 — 音源管理 + 关于
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceProvider);

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
                    icon: Icons.source,
                    title: '已导入源脚本（旧版）',
                    subtitle: '${sources.length} 个源（${sources.where((s) => s.enabled).length} 个启用）',
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
                          ref.read(sourceProvider.notifier).toggleEnabled(source.id);
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
          '源脚本管理',
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
                    '还没有导入源脚本',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右上角 + 导入 LX Music 源脚本',
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
                          Icons.code_rounded,
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
                      subtitle: _buildSourceSubtitle(source),
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

  Widget _buildSourceSubtitle(MusicSource source) {
    final keys = source.sourceKeys;
    final versionInfo = source.version != null ? ' v${source.version}' : '';

    if (keys.isNotEmpty) {
      final sourceNames = keys.map((k) {
        final src = source.parsedSources?[k] as Map<String, dynamic>?;
        return src?['name'] as String? ?? k;
      }).join(', ');
      return Text(
        '$sourceNames$versionInfo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      );
    }

    if (source.description != null) {
      return Text(
        '${source.description!}$versionInfo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      );
    }

    return Text(
      '源脚本$versionInfo',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    final scriptController = TextEditingController();
    final dialogState = _DialogState();
    var importMode = 0; // 0 = URL, 1 = 粘贴
    Map<String, String?>? scriptMeta;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          dialogState._setState = setDialogState;

          return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassPanel(
            blur: 20,
            borderRadius: 24,
            tintColor: AppColors.surfaceDark,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '导入源脚本',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // 模式切换
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() { importMode = 0; dialogState.error = null; });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: importMode == 0
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'URL 导入',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: importMode == 0
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() { importMode = 1; dialogState.error = null; });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: importMode == 1
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '粘贴脚本',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: importMode == 1
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // URL 模式
                  if (importMode == 0) ...[
                    _GlassInput(
                      controller: urlController,
                      hint: '源脚本 URL（.js 文件地址）',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持 LX Music 源脚本 (.js) URL',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // 粘贴模式
                  if (importMode == 1) ...[
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textTertiary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: TextField(
                        controller: scriptController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: '在此粘贴 LX Music 源脚本内容...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (_) {
                          final meta = ref
                              .read(sourceProvider.notifier)
                              .parseScriptMeta(scriptController.text);
                          setDialogState(() { scriptMeta = meta.isNotEmpty ? meta : null; });
                        },
                      ),
                    ),

                    // 从剪贴板读取按钮
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null && data!.text!.isNotEmpty) {
                              scriptController.text = data.text!;
                              final meta = ref
                                  .read(sourceProvider.notifier)
                                  .parseScriptMeta(scriptController.text);
                              setDialogState(() { scriptMeta = meta.isNotEmpty ? meta : null; });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.paste_rounded, size: 14,
                                    color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('从剪贴板读取',
                                    style: TextStyle(fontSize: 12,
                                        color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 脚本元信息展示
                    if (scriptMeta != null && scriptMeta!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('检测到脚本信息',
                                style: TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                            const SizedBox(height: 6),
                            if (scriptMeta!['name'] != null)
                              _metaRow('名称', scriptMeta!['name']!),
                            if (scriptMeta!['version'] != null)
                              _metaRow('版本', scriptMeta!['version']!),
                            if (scriptMeta!['author'] != null)
                              _metaRow('作者', scriptMeta!['author']!),
                            if (scriptMeta!['description'] != null)
                              _metaRow('描述', scriptMeta!['description']!),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // 错误提示
                  if (dialogState.error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogState.error!,
                        style: TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: dialogState.loading ? null : () => Navigator.pop(ctx),
                        child: Text('取消',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      GlassPanel(
                        blur: 10,
                        borderRadius: 12,
                        tintColor: AppColors.primary.withValues(alpha: 0.3),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: GestureDetector(
                            onTap: dialogState.loading
                                ? null
                                : () => _doImport(ctx, ref, dialogState,
                                    importMode, urlController,
                                    scriptController),
                            child: dialogState.loading
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('导入',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ); },
      ),
    );
  }

  Future<void> _doImport(
    BuildContext ctx,
    WidgetRef ref,
    _DialogState dialogState,
    int importMode,
    TextEditingController urlController,
    TextEditingController scriptController,
  ) async {
    dialogState._setState!(() {
      dialogState.loading = true;
      dialogState.error = null;
    });

    final notifier = ref.read(sourceProvider.notifier);
    ImportResult result;

    if (importMode == 1) {
      final script = scriptController.text.trim();
      if (script.isEmpty) {
        dialogState._setState!(() {
          dialogState.loading = false;
          dialogState.error = '请先粘贴脚本内容';
        });
        return;
      }
      result = await notifier.importFromScript(script);
    } else {
      final url = urlController.text.trim();
      if (url.isEmpty) {
        dialogState._setState!(() {
          dialogState.loading = false;
          dialogState.error = '请输入源脚本 URL';
        });
        return;
      }
      result = await notifier.importFromUrl(url);
    }

    if (!ctx.mounted) return;

    if (result.success) {
      Navigator.pop(ctx);
      // 显示导入成功的源信息
      final source = result.source;
      final keys = source?.sourceKeys ?? [];
      final sourceNames = keys.map((k) {
        final src = source?.parsedSources?[k] as Map<String, dynamic>?;
        return src?['name'] as String? ?? k;
      }).join(', ');

      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(keys.isNotEmpty
              ? '源脚本导入成功：$sourceNames'
              : '源脚本导入成功'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      dialogState._setState!(() {
        dialogState.loading = false;
        dialogState.error = result.error;
      });
    }
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text('$label:',
                style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 11,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// 对话框可变状态持有者
class _DialogState {
  bool loading = false;
  String? error;
  void Function(void Function())? _setState;
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
