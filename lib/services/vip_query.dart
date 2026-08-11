import 'dart:convert';

import 'package:dio/dio.dart';

import '../music_source/auth/netease_weapi.dart';

/// 平台 VIP 状态（账号中心展示用）
class VipStatus {
  final String platformKey;
  final bool isVip;

  /// 会员标签（如「豪华绿钻 Lv7」「黑胶VIP」）
  final String label;

  /// 过期时间文本（可选，如「2025-12-31」）
  final String? expireText;

  /// 查询是否仍进行中
  final bool loading;

  /// 查询失败信息（null 表示成功/未失败）
  final String? error;

  const VipStatus({
    required this.platformKey,
    this.isVip = false,
    this.label = '',
    this.expireText,
    this.loading = false,
    this.error,
  });

  VipStatus copyWith({
    bool? isVip,
    String? label,
    String? expireText,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return VipStatus(
      platformKey: platformKey,
      isVip: isVip ?? this.isVip,
      label: label ?? this.label,
      expireText: expireText ?? this.expireText,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory VipStatus.loading(String platformKey) =>
      VipStatus(platformKey: platformKey, loading: true);
}

/// 查询网易云 VIP：weapi /weapi/nuser/account/get 的 profile.vipType
///
/// vipType 0 = 普通用户，11 = 黑胶VIP（web 端红钻）。失败返回 null。
Future<VipStatus?> queryNeteaseVip(Dio dio, {required String cookie}) async {
  if (cookie.isEmpty) return null;
  final data = await NeteaseWeapi.weapiPost(
    dio,
    path: '/weapi/nuser/account/get',
    params: const {},
    cookie: cookie,
  );
  final profile = (data?['profile'] as Map?)?.cast<String, dynamic>();
  if (profile == null) return null;
  final vipType = profile['vipType'] is num
      ? (profile['vipType'] as num).toInt()
      : 0;
  return VipStatus(
    platformKey: 'wy',
    isVip: vipType != 0,
    label: vipType == 11
        ? '黑胶VIP'
        : vipType > 0
            ? 'VIP'
            : '普通用户',
  );
}

/// 查询 QQ 音乐 VIP：musicu.fcg userInfo.VipQueryServer / SRFVipQuery_V2
///
/// 与 Mineradio 的 fetchQQVipStatus 一致：comm.authst 携带 qm_keyst/qqmusic_key
/// 识别会员身份，uin_list 查询（VIP 查询不需要 guid，与 CgiGetVkey 不同）。
/// 响应字段见 [kQqVipFlagKeys] 等。
Future<VipStatus?> queryQqVip(
  Dio dio, {
  required String cookie,
}) async {
  if (cookie.isEmpty) return null;
  // uin 与播放授权 key 都缺失时查询没有意义（无会员身份）
  final uin = _extractQqUin(cookie);
  if (uin.isEmpty) return null;

  final musicKey = _extractQqMusicKey(cookie);
  final comm = <String, dynamic>{
    'uin': uin,
    'format': 'json',
    'ct': 24,
    'cv': 0,
    if (musicKey.isNotEmpty) 'authst': musicKey,
  };
  final payload = {
    'comm': comm,
    'req_1': {
      'module': 'userInfo.VipQueryServer',
      'method': 'SRFVipQuery_V2',
      'param': {'uin_list': [uin]},
    },
  };
  try {
    final resp = await dio.post<String>(
      'https://u.y.qq.com/cgi-bin/musicu.fcg',
      data: jsonEncode(payload),
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://y.qq.com/',
          'Cookie': cookie,
        },
        contentType: 'application/json',
        responseType: ResponseType.plain,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );
    final text = resp.data;
    if (text == null || text.trim().isEmpty) return null;
    final decoded = jsonDecode(text);
    if (decoded is! Map) return null;
    final map = decoded.cast<String, dynamic>();

    // 依次尝试 req_1 / vip / data 路径，取首个含会员字段的对象
    Map<String, dynamic>? vipObj;
    for (final key in const ['req_1', 'vip', 'data']) {
      final node = map[key];
      final found = _findVipObject(node);
      if (found != null) {
        vipObj = found;
        break;
      }
    }
    if (vipObj == null) return null;

    final isVip = _anyTrue(vipObj, kQqVipFlagKeys);
    final svip = _anyTrue(vipObj, kQqSvipFlagKeys);
    final vipType = _firstInt(vipObj, const ['musicviptype', 'viptype']);
    final vipLevel = _firstInt(vipObj, const ['musicviplevel', 'viplevel']);
    final expire = _firstInt(
      vipObj,
      const ['musicvipexpiretime', 'vipexpiretime', 'vipendtime'],
    );

    return VipStatus(
      platformKey: 'tx',
      isVip: isVip || svip || (vipType != null && vipType > 0),
      label: _qqVipLabel(vipType, vipLevel, svip),
      expireText: _formatExpire(expire),
    );
  } catch (_) {
    return null;
  }
}

/// 从任意节点中递归查找会员信息对象
Map<String, dynamic>? _findVipObject(dynamic node) {
  if (node is Map) {
    final m = node.cast<String, dynamic>();
    if (m.keys.any(kQqVipFlagKeys.contains) ||
        m.keys.any(kQqSvipFlagKeys.contains)) {
      return m;
    }
    // data 可能是列表（uin_list 对应）
    for (final v in m.values) {
      final found = _findVipObject(v);
      if (found != null) return found;
    }
    return null;
  }
  if (node is List) {
    for (final v in node) {
      final found = _findVipObject(v);
      if (found != null) return found;
    }
  }
  return null;
}

/// QQ 会员标识键（值为 true/1 表示会员）
const Set<String> kQqVipFlagKeys = {
  'isvip',
  'ivipflag',
  'inewvip',
  'vip',
  'vipflag',
  'ismember',
  'member',
  'isgreenvip',
  'greenvip',
  'isassociator',
  'associator',
};

/// QQ 超级会员标识键
const Set<String> kQqSvipFlagKeys = {
  'issvip',
  'isupervip',
  'inewsupervip',
  'svip',
  'issupervip',
  'supervip',
  'isluxuryvip',
  'luxuryvip',
};

bool _anyTrue(Map<String, dynamic> m, Set<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == true || v == 1) return true;
    if (v is String && (v == 'true' || v == '1')) return true;
  }
  return false;
}

int? _firstInt(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toInt();
    final n = int.tryParse('$v');
    if (n != null) return n;
  }
  return null;
}

/// QQ 音乐会员类型 → 展示标签
String _qqVipLabel(int? vipType, int? vipLevel, bool svip) {
  if (svip) {
    final lv = vipLevel != null && vipLevel > 0 ? ' Lv$vipLevel' : '';
    return '超级会员$lv';
  }
  final label = switch (vipType) {
    1 => '豪华绿钻',
    2 => '付费音乐包',
    3 => '豪华绿钻+付费音乐包',
    7 => '超级会员',
    8 => '豪华绿钻',
    null => '',
    _ => 'VIP',
  };
  if (label.isEmpty) return '';
  final lv = vipLevel != null && vipLevel > 0 ? ' Lv$vipLevel' : '';
  return '$label$lv';
}

String? _formatExpire(int? ts) {
  if (ts == null || ts <= 0) return null;
  final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  final now = DateTime.now();
  if (dt.isBefore(now)) return '已过期';
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 到期';
}

String _extractQqUin(String cookie) {
  for (final key in const ['uin', 'qqmusic_uin', 'wxuin', 'p_uin']) {
    final m = RegExp('(?:^|;)\\s*$key=([^;]+)').firstMatch(cookie);
    if (m != null && (m.group(1) ?? '').isNotEmpty) return m.group(1)!;
  }
  return '';
}

String _extractQqMusicKey(String cookie) {
  for (final key in const ['qm_keyst', 'qqmusic_key', 'music_key', 'wxskey']) {
    final m = RegExp('(?:^|;)\\s*$key=([^;]+)').firstMatch(cookie);
    if (m != null && (m.group(1) ?? '').isNotEmpty) return m.group(1)!;
  }
  return '';
}
