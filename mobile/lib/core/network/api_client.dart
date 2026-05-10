import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  final _storage = const FlutterSecureStorage();
  late final Dio dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

  Future<void> saveToken(String token) =>
      _storage.write(key: 'access_token', value: token);

  Future<void> clearToken() => _storage.delete(key: 'access_token');

  Future<String?> getToken() => _storage.read(key: 'access_token');
}
