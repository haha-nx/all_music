import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../music_source/builtin/builtin_platforms.dart';
import '../../providers/account_center_provider.dart';
import '../../providers/account_vip_provider.dart';
import '../../services/cookie_analyzer.dart';
import '../../services/cookie_bridge.dart';
import '../../services/cookie_store.dart';
import '../../services/vip_query.dart';
import '../../widgets/glass_panel.dart';
import 'platform_login_screen.dart';

/// 各平台登录页 URL 与 cookie 域映射（sourceKey → 登录信息）
/// loginUrl 用 PC 版登录入口（配合桌面 UA），cookieUrl 是 cookie 所属域
const Map<String, ({String loginUrl, String cookieUrl})> kPlatformLoginInfo = {
  'wy': (
    loginUrl: 'https://music.163.com/',
    cookieUrl: 'https://music.163.com',
  ),
  'tx': (loginUrl: 'https://y.qq.com/', cookieUrl: 'https://y.qq.com'),
  'kg': (
    loginUrl: 'https://www.kugou.com/',
    cookieUrl: 'https://www.kugou.com',
  ),
  'kw': (loginUrl: 'https://www.kuwo.cn/', cookieUrl: 'https://www.kuwo.cn'),
  'mg': (loginUrl: 'https://music.migu.cn/', cookieUrl: 'https://www.migu.cn'),
};

/// 平台主题色（sourceKey → 品牌色）
const Map<String, Color> kPlatformColors = {
  'wy': Color(0xFFE60026),
  'tx': Color(0xFF31C27C),
  'kg': Color(0xFF24ACF2),
  'kw': Color(0xFF7C4DFF),
  'mg': Color(0xFF0AA8E8),
};

/// 账号中心：管理各内置平台的登录态，展示 VIP 会员情况
class AccountCenterScreen extends ConsumerWidget {
  const AccountCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(accountCenterProvider);
    final vip = ref.watch(accountVipProvider);

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
                8,
              ),
              child: Text(
                '账号中心',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          // 说明卡片
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.paddingH,
                0,
                AppSizes.paddingH,
                16,
              ),
              child: GlassPanel(
                blur: 12,
                borderRadius: 16,
                tintColor: AppColors.primary.withValues(alpha: 0.08),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '登录后，内置音源将使用你的账号播放（VIP 歌曲可播），'
                          '并同步各平台的会员状态。登录态仅保存在本机，不会上传。',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 平台列表
          for (final platform in kBuiltinPlatforms)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingH,
                  vertical: 4,
                ),
                child: _PlatformCard(
                  platform: platform,
                  credential: credentials[platform.sourceKey],
                  vipStatus: vip[platform.sourceKey],
                  onLogin: () async {
                    final info = kPlatformLoginInfo[platform.sourceKey]!;
                    final cookie = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlatformLoginScreen(
                          platformKey: platform.sourceKey,
                          platformName: platform.name,
                          loginUrl: info.loginUrl,
                          cookieUrl: info.cookieUrl,
                        ),
                      ),
                    );
                    if (cookie != null && cookie.isNotEmpty) {
                      ref
                          .read(accountCenterProvider.notifier)
                          .setCookie(platform.sourceKey, cookie);
                      // 登录态反馈：关键键齐全才算真正登录成功
                      if (!context.mounted) return;
                      final missing = missingLoginKeys(
                        platform.sourceKey,
                        cookie,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            missing.isEmpty
                                ? '${platform.name} 登录成功（VIP 播放可用）'
                                : '${platform.name} cookie 已保存，但登录态不完整（缺 '
                                      '${missing.join('、')}），播放可能仍失败',
                          ),
                        ),
                      );
                    }
                  },
                  onLogout: () {
                    ref
                        .read(accountCenterProvider.notifier)
                        .logout(platform.sourceKey);
                    CookieBridge.clearCookie();
                  },
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final BuiltinPlatform platform;
  final AccountCredential? credential;
  final VipStatus? vipStatus;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const _PlatformCard({
    required this.platform,
    required this.credential,
    required this.vipStatus,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final loggedIn = credential?.isLoggedIn ?? false;
    final color = kPlatformColors[platform.sourceKey] ?? AppColors.primary;

    return GlassPanel(
      blur: 12,
      borderRadius: 18,
      tintColor: loggedIn
          ? color.withValues(alpha: 0.08)
          : AppColors.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // 平台图标
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.9),
                        color.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      platform.name.substring(0, 1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // 平台名 + 登录状态
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platform.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _buildStatusText(color),
                    ],
                  ),
                ),
                // 登录/退出
                if (!loggedIn)
                  _buildActionButton(
                    label: '登录',
                    background: color,
                    onTap: onLogin,
                  )
                else
                  _buildActionButton(
                    label: '退出',
                    background: Colors.transparent,
                    borderColor: AppColors.textTertiary.withValues(alpha: 0.4),
                    textColor: AppColors.textSecondary,
                    onTap: onLogout,
                  ),
              ],
            ),

            // VIP 状态（仅登录后显示）
            if (loggedIn) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: AppColors.textTertiary.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              _buildVipRow(),
            ],
          ],
        ),
      ),
    );
  }

  /// 登录状态副标题（未登录 / 已登录日期 / 登录态不完整）
  Widget _buildStatusText(Color color) {
    if (credential == null || !credential!.isLoggedIn) {
      return Text(
        '未登录',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      );
    }
    final missing = missingLoginKeys(platform.sourceKey, credential!.cookie);
    final dateText = credential!.loggedInAt.toLocal().toString().substring(
      0,
      10,
    );
    if (missing.isEmpty) {
      return Text(
        '已登录 $dateText',
        style: TextStyle(fontSize: 13, color: color),
      );
    }
    return Text(
      '已登录（登录态不完整：缺 ${missing.join('、')}，请重新登录）',
      style: TextStyle(fontSize: 12, color: Colors.orange.shade300),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color background,
    VoidCallback? onTap,
    Color? borderColor,
    Color? textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// VIP 状态行：加载中 / VIP 徽标 + 到期时间 / 获取失败
  Widget _buildVipRow() {
    final status = vipStatus;

    if (status == null || status.loading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '正在查询会员状态...',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    if (status.error != null) {
      return Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            status.error!,
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      );
    }

    // VIP 徽标（金色渐变）
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: status.isVip
                  ? const [Color(0xFFFFD54F), Color(0xFFFFA000)]
                  : [AppColors.surfaceLight, AppColors.surfaceLight],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status.isVip
                    ? Icons.workspace_premium_rounded
                    : Icons.person_outline,
                size: 14,
                color: status.isVip
                    ? const Color(0xFF5D4037)
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                status.label.isNotEmpty
                    ? status.label
                    : (status.isVip ? 'VIP' : '普通用户'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: status.isVip
                      ? const Color(0xFF5D4037)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (status.expireText != null) ...[
          const SizedBox(width: 10),
          Text(
            status.expireText!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
