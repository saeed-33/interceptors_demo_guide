// lib/core/interceptors/auth_interceptor.dart
//
// 🔑 AUTH INTERCEPTOR
// Attaches Bearer token to every request.
// Auto-refreshes token on 401 and retries the original request.
// On refresh failure, logs out the user and redirects to login.

import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';
import 'package:interceptors_demo/core/navigation/app_router.dart';
import 'package:interceptors_demo/core/storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final TokenStorage _tokenStorage;
  bool _isRefreshing = false;

  // Queue of requests that were waiting for token refresh
  final List<_PendingRequest> _pendingRequests = [];

  /// Public auth endpoints that must never send an Authorization header.
  static const _publicAuthPaths = {
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/logout',
  };

  AuthInterceptor({
    required Dio dio,
    TokenStorage? tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage ?? TokenStorage.create();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final requestId = options.extra['request_id'] as String? ?? options.path;

    // Skip auth for public endpoints (login, register, refresh, logout).
    // We also remove any stale Authorization header so these requests never
    // send a token, even if one happens to be in storage.
    final isPublic = options.extra['skipAuth'] == true ||
        _publicAuthPaths.any((p) => options.path.startsWith(p));
    if (isPublic) {
      options.headers.remove('Authorization');
      logInterceptor(
        'auth',
        'skip auth for ${options.path}',
        api: options.path,
        requestId: requestId,
      );
      return handler.next(options);
    }

    final token = await _tokenStorage.read('access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      logInterceptor(
        'auth',
        'attach bearer token to ${options.path}',
        api: options.path,
        requestId: requestId,
      );
    } else {
      logInterceptor(
        'auth',
        'no token available for ${options.path}',
        api: options.path,
        requestId: requestId,
      );
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestId = err.requestOptions.extra['request_id'] as String? ??
        err.requestOptions.path;

    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    logInterceptor(
      'auth',
      'received 401 for ${err.requestOptions.path}',
      api: err.requestOptions.path,
      requestId: requestId,
    );

    // If already refreshing, queue this request
    if (_isRefreshing) {
      logInterceptor(
        'auth',
        'token refresh in progress — queue request',
        api: err.requestOptions.path,
        requestId: requestId,
      );
      final completer = _PendingRequest(err.requestOptions, handler);
      _pendingRequests.add(completer);
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _tokenStorage.read('refresh_token');
      if (refreshToken == null) throw Exception('No refresh token');

      logInterceptor(
        'auth',
        'refresh access token',
        api: err.requestOptions.path,
        requestId: requestId,
      );
      // Call refresh endpoint (skip auth interceptor to avoid loops)
      final refreshResponse = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );

      final newToken = refreshResponse.data['data']['access_token'] as String;
      final newRefreshToken = refreshResponse.data['data']['refresh_token'] as String;
      await _tokenStorage.write('access_token', newToken);
      await _tokenStorage.write('refresh_token', newRefreshToken);
      logInterceptor(
        'auth',
        'token refreshed successfully',
        api: err.requestOptions.path,
        requestId: requestId,
      );

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
    } catch (e) {
      // Refresh failed — clear tokens and go to login
      logInterceptor(
        'auth',
        'refresh failed — log out ($e)',
        api: err.requestOptions.path,
        requestId: requestId,
      );
      await _tokenStorage.deleteAll();
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
