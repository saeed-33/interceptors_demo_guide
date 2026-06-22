// lib/core/interceptors/auth_interceptor.dart
//
// 🔑 AUTH INTERCEPTOR
// Attaches Bearer token to every request.
// Auto-refreshes token on 401 and retries the original request.
// On refresh failure, logs out the user and redirects to login.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:interceptors_demo/core/navigation/app_router.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  bool _isRefreshing = false;

  // Queue of requests that were waiting for token refresh
  final List<_PendingRequest> _pendingRequests = [];

  AuthInterceptor({
    required Dio dio,
    FlutterSecureStorage? secureStorage,
  })  : _dio = dio,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for public endpoints
    if (options.extra['skipAuth'] == true) {
      return handler.next(options);
    }

    final token = await _secureStorage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // If already refreshing, queue this request
    if (_isRefreshing) {
      final completer = _PendingRequest(err.requestOptions, handler);
      _pendingRequests.add(completer);
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) throw Exception('No refresh token');

      // Call refresh endpoint (skip auth interceptor to avoid loops)
      final refreshResponse = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );

      final newToken = refreshResponse.data['access_token'] as String;
      await _secureStorage.write(key: 'access_token', value: newToken);

      // Retry all pending requests with new token
      for (final pending in _pendingRequests) {
        pending.options.headers['Authorization'] = 'Bearer $newToken';
        final retryResponse = await _dio.fetch(pending.options);
        pending.handler.resolve(retryResponse);
      }
      _pendingRequests.clear();

      // Retry original request
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      final retried = await _dio.fetch(err.requestOptions);
      return handler.resolve(retried);
    } catch (_) {
      // Refresh failed — clear tokens and go to login
      await _secureStorage.deleteAll();
      _pendingRequests.clear();

      // Navigate to login screen
      AppRouter.navigatorKey.currentContext?.go('/login');

      return handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}

class _PendingRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _PendingRequest(this.options, this.handler);
}
