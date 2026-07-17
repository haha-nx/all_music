/// 音源类型枚举
enum SourceType {
  local('本地文件', 'local'),
  online('在线音源', 'online');

  final String label;
  final String key;
  const SourceType(this.label, this.key);

  static SourceType fromKey(String key) {
    return SourceType.values.firstWhere(
      (s) => s.key == key,
      orElse: () => SourceType.local,
    );
  }
}
