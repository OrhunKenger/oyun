import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../../../core/network/api_client.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthRemoteDatasource());
});

class AuthState {
  final bool isLoading;
  final String? error;
  final String? userId;
  final String? username;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.userId,
    this.username,
  });

  bool get isAuthenticated => userId != null;

  AuthState copyWith({bool? isLoading, String? error, String? userId, String? username}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        userId: userId ?? this.userId,
        username: username ?? this.username,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRemoteDatasource _ds;
  final _googleSignIn = GoogleSignIn(scopes: ['email']);

  AuthNotifier(this._ds) : super(const AuthState()) {
    _checkToken();
  }

  Future<void> _checkToken() async {
    final token = await ApiClient().getToken();
    if (token != null) {
      state = state.copyWith(userId: 'cached');
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _ds.login(email, password);
      await ApiClient().saveToken(res.accessToken);
      state = state.copyWith(isLoading: false, userId: res.userId, username: res.username);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> register(String email, String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _ds.register(email, username, password);
      await ApiClient().saveToken(res.accessToken);
      state = state.copyWith(isLoading: false, userId: res.userId, username: res.username);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> googleSignIn() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      final auth = await account.authentication;
      final res = await _ds.socialAuth('google', auth.idToken!);
      await ApiClient().saveToken(res.accessToken);
      state = state.copyWith(isLoading: false, userId: res.userId, username: res.username);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient().clearToken();
    await _googleSignIn.signOut();
    state = const AuthState();
  }

  String _parseError(dynamic e) {
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return 'Bir hata oluştu';
  }
}
