import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/auth_model.dart';

class AuthRemoteDatasource {
  final Dio _dio = ApiClient().dio;

  Future<AuthResponse> register(String email, String username, String password) async {
    final res = await _dio.post('/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
    });
    return AuthResponse.fromJson(res.data);
  }

  Future<AuthResponse> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(res.data);
  }

  Future<AuthResponse> socialAuth(String provider, String token) async {
    final res = await _dio.post('/auth/social', data: {
      'provider': provider,
      'token': token,
    });
    return AuthResponse.fromJson(res.data);
  }
}
