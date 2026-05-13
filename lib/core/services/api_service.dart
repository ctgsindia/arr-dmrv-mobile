/// @file api_service.dart
/// @description Dio HTTP client with interceptors for the ARR DMRV backend.
///   - Auth: Bearer token injection + auto-refresh on 401
///   - Connectivity: offline → throws OfflineException → SyncService queues the request
///   - Response: unwraps {success, data, meta} envelope; throws ApiException on errors
///
/// Called by: all feature providers
/// Uses: SharedPreferences for token storage
library;

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/api_config.dart';

// ─── Exceptions ───────────────────────────────────────────────────────────────

class OfflineException implements Exception {
  final String message;
  const OfflineException([this.message = 'No internet connection']);
  @override
  String toString() => 'OfflineException: $message';
}

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  const ApiException({required this.statusCode, required this.code, required this.message});
  @override
  String toString() => 'ApiException($statusCode): [$code] $message';
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final apiServiceProvider = Provider<ApiService>((ref) => ApiService(ref));

// ─── Constants ────────────────────────────────────────────────────────────────

const _kAccessToken  = 'arr_access_token';
const _kRefreshToken = 'arr_refresh_token';

// ─── Service ──────────────────────────────────────────────────────────────────

class ApiService {
  final Ref _ref;
  late final Dio _dio;

  bool _isRefreshing = false;
  final List<void Function(String?)> _refreshQueue = [];

  ApiService(this._ref) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (ApiConfig.isNgrok) 'ngrok-skip-browser-warning': 'true',
        'User-Agent': 'ArrDmrvMobile/1.0 Flutter',
      },
    ));

    _dio.interceptors.addAll([
      _ConnectivityInterceptor(),
      _AuthInterceptor(this),
      _ResponseInterceptor(),
      if (kDebugMode)
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
          error: true,
          logPrint: (o) => debugPrint('🌿 $o'),
        ),
    ]);
  }

  // ─── Token helpers ────────────────────────────────────────────────────────

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessToken);
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kRefreshToken, refreshToken);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
  }

  // ─── Refresh logic ────────────────────────────────────────────────────────

  Future<String?> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_kRefreshToken);
    if (refreshToken == null) return null;

    if (_isRefreshing) {
      final completer = Completer<String?>();
      _refreshQueue.add(completer.complete);
      return completer.future;
    }

    _isRefreshing = true;
    try {
      final res = await _dio.post(
        ApiConfig.refresh,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Authorization': null}),
      );
      final newAccess  = res.data['data']['accessToken'] as String;
      final newRefresh = res.data['data']['refreshToken'] as String? ?? refreshToken;
      await saveTokens(newAccess, newRefresh);
      for (final cb in _refreshQueue) { cb(newAccess); }
      _refreshQueue.clear();
      return newAccess;
    } catch (_) {
      for (final cb in _refreshQueue) { cb(null); }
      _refreshQueue.clear();
      await clearTokens();
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  // ─── Public HTTP helpers ──────────────────────────────────────────────────

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data, Options? options}) =>
      _dio.post(path, data: data, options: options);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  Future<Response> upload(String path, FormData formData) =>
      _dio.post(path, data: formData, options: Options(contentType: 'multipart/form-data'));

  /// Upload a photo file; returns the server URL.
  Future<String> uploadPhotoFile(String filePath) async {
    final fileName = filePath.split('/').last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await upload(ApiConfig.photoUpload, form);
    final url = (res.data['data'] as Map<String, dynamic>?)?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const ApiException(statusCode: 500, code: 'UPLOAD_FAILED', message: 'No photo URL returned');
    }
    return url;
  }
}

// ─── Interceptors ─────────────────────────────────────────────────────────────

class _ConnectivityInterceptor extends Interceptor {
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      return handler.reject(
        DioException(requestOptions: options, error: const OfflineException(), type: DioExceptionType.connectionError),
        true,
      );
    }
    super.onRequest(options, handler);
  }
}

class _AuthInterceptor extends Interceptor {
  final ApiService _service;
  _AuthInterceptor(this._service);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _service.getAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final newToken = await _service.refreshAccessToken();
      if (newToken != null) {
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        try {
          final retry = await _service._dio.fetch(opts);
          return handler.resolve(retry);
        } catch (_) {}
      }
    }
    handler.next(err);
  }
}

class _ResponseInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map && data['success'] == false) {
      final error = data['error'] as Map<String, dynamic>? ?? {};
      throw ApiException(
        statusCode: response.statusCode ?? 0,
        code: error['code']?.toString() ?? 'UNKNOWN',
        message: error['msg']?.toString() ?? 'Unknown error',
      );
    }
    handler.next(response);
  }
}
