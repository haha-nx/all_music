/// 内置音乐平台元数据
class BuiltinPlatform {
  final String id;
  final String name;
  final String sourceKey;

  const BuiltinPlatform({
    required this.id,
    required this.name,
    required this.sourceKey,
  });
}

/// 内置搜索平台列表（与官方 lx-music-mobile 的在线源保持一致）
const List<BuiltinPlatform> kBuiltinPlatforms = [
  BuiltinPlatform(id: 'builtin_wy', name: '网易云音乐', sourceKey: 'wy'),
  BuiltinPlatform(id: 'builtin_tx', name: 'QQ音乐', sourceKey: 'tx'),
  BuiltinPlatform(id: 'builtin_kg', name: '酷狗音乐', sourceKey: 'kg'),
  BuiltinPlatform(id: 'builtin_kw', name: '酷我音乐', sourceKey: 'kw'),
  BuiltinPlatform(id: 'builtin_mg', name: '咪咕音乐', sourceKey: 'mg'),
];

/// 平台 key → 显示名（搜索结果徽标用）
const Map<String, String> kSourceKeyNames = {
  'wy': '网易云',
  'tx': 'QQ音乐',
  'kg': '酷狗',
  'kw': '酷我',
  'mg': '咪咕',
};
