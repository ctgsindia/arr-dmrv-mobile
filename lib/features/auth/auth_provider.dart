/// @file auth_provider.dart
/// @description Riverpod AuthNotifier for ARR DMRV.
///   Manages JWT session: login, logout, restore from SharedPreferences.
///
/// Called by: login_screen.dart, app_router.dart
/// Uses: ApiService
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/api_service.dart';
import '../../core/config/api_config.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? tenantId;
  final String? email;
  final String? role;
  final String? name;
  final bool loading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.tenantId,
    this.email,
    this.role,
    this.name,
    this.loading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated, String? userId, String? tenantId, String? email,
    String? role, String? name, bool? loading, String? error,
  }) => AuthState(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    userId: userId ?? this.userId,
    tenantId: tenantId ?? this.tenantId,
    email: email ?? this.email,
    role: role ?? this.role,
    name: name ?? this.name,
    loading: loading ?? this.loading,
    error: error,
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    _restoreSession();
  }

  /// Restore session from stored JWT by calling /me.
  Future<void> _restoreSession() async {
    final token = await _api.getAccessToken();
    if (token == null) return;
    try {
      final res = await _api.get(ApiConfig.me);
      final user = res.data['data'] as Map<String, dynamic>;
      state = AuthState(
        isAuthenticated: true,
        userId:   user['id'] as String?,
        tenantId: user['tenantId'] as String?,
        email:    user['email'] as String?,
        role:     user['role'] as String?,
        name:     user['name'] as String?,
      );
    } catch (_) {
      await _api.clearTokens();
    }
  }

  /// Log in with email + password.
  ///
  /// @param email     User email
  /// @param password  Plain-text password
  /// @throws [ApiException] on invalid credentials
  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.post(ApiConfig.login, data: {'email': email, 'password': password});
      final data = res.data['data'] as Map<String, dynamic>;
      await _api.saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
      final user = data['user'] as Map<String, dynamic>;
      state = AuthState(
        isAuthenticated: true,
        userId:   user['id'] as String?,
        tenantId: user['tenantId'] as String?,
        email:    user['email'] as String?,
        role:     user['role'] as String?,
        name:     user['name'] as String?,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      rethrow;
    } on DioException catch (e) {
      final msg = switch (e.type) {
        DioExceptionType.connectionError || DioExceptionType.unknown =>
          'Cannot reach server. Run: adb reverse tcp:3001 tcp:3001',
        DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout =>
          'Request timed out.',
        _ => e.message ?? 'Network error.',
      };
      state = state.copyWith(loading: false, error: msg);
      rethrow;
    }
  }

  /// Log out — clear tokens and reset state.
  Future<void> logout() async {
    await _api.clearTokens();
    state = const AuthState();
  }
}
