import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../music_source/providers/music_source_provider.dart';
import '../services/vip_query.dart';
import 'account_center_provider.dart';

/// 各平台 VIP 状态（仅展示已登录平台，未登录不查询）
final accountVipProvider = StateNotifierProvider<AccountVipNotifier,
    Map<String, VipStatus>>((ref) => AccountVipNotifier(ref));

class AccountVipNotifier extends StateNotifier<Map<String, VipStatus>> {
  final Ref ref;
  late final Dio _dio;

  AccountVipNotifier(this.ref) : super({}) {
    // dio 为全局单例，构造器内只读一次（initializer 中不能访问 this.ref）
    _dio = ref.read(dioProvider);
    // 登录态变化时：新登录的平台自动查询，登出的平台清除
    ref.listen(accountCenterProvider, (prev, next) {
      for (final key in next.keys) {
        if (prev?[key] == null && state[key] == null) {
          refresh(key);
        }
      }
      for (final key in [...state.keys]) {
        if (!next.containsKey(key)) {
          state = {...state}..remove(key);
        }
      }
    });
    // 初始：对已登录平台查询（登录态由 CookieStore 异步加载，通常已就绪）
    for (final key in ref.read(accountCenterProvider).keys) {
      if (state[key] == null) {
        refresh(key);
      }
    }
  }

  /// 查询某平台 VIP 状态（未登录直接跳过）
  Future<void> refresh(String platformKey) async {
    final credential = ref.read(accountCenterProvider)[platformKey];
    if (credential == null || !credential.isLoggedIn) return;

    state = {...state, platformKey: VipStatus.loading(platformKey)};
    try {
      final status = switch (platformKey) {
        'wy' => await queryNeteaseVip(_dio, cookie: credential.cookie),
        'tx' => await queryQqVip(_dio, cookie: credential.cookie),
        _ => null,
      };
      // 查询期间可能已登出：写回前校验登录态仍在，避免把已清除的平台重新加回
      final stillLoggedIn =
          ref.read(accountCenterProvider)[platformKey]?.isLoggedIn ?? false;
      if (!stillLoggedIn) return;
      if (status != null) {
        state = {...state, platformKey: status};
      } else {
        state = {
          ...state,
          platformKey: VipStatus(
            platformKey: platformKey,
            error: 'VIP 状态获取失败',
          ),
        };
      }
    } catch (_) {
      state = {
        ...state,
        platformKey: VipStatus(platformKey: platformKey, error: 'VIP 状态获取失败'),
      };
    }
  }
}
