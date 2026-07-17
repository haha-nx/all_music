import 'package:dio/dio.dart';

/// 统一 HTTP 客户端
class MusicHttpClient {
  static final MusicHttpClient _instance = MusicHttpClient._internal();
  factory MusicHttpClient() => _instance;
  MusicHttpClient._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ));
  }

  late final Dio _dio;
  Dio get dio => _dio;
}
