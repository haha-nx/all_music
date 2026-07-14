/// 音源类型枚举
enum SourceType {
  local('本地文件', 'local'),
  api('在线音源', 'api');

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
