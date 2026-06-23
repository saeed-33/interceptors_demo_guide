// lib/core/security/bio_auth_interceptor.dart
//
// 🔐 BIOMETRIC AUTH INTERCEPTOR
// Forces biometric authentication when app returns from background.
// Can also protect specific API calls (e.g., payment, profile change).

import 'package:local_auth/local_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';

class BioAuthInterceptor {
  static final instance = BioAuthInterceptor._();
  BioAuthInterceptor._();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticated = false;

  /// Call when app resumes from background
  /// [api] is the request path or logical group this biometric prompt belongs to.
  /// [requestId] groups this biometric prompt with the API request it protects.
  Future<void> authenticate({
    String api = 'startup',
    String requestId = 'startup',
  }) async {
    logInterceptor(
      'bio auth',
      'request biometric authentication',
      api: api,
      requestId: requestId,
    );

    if (kIsWeb) {
      logInterceptor(
        'bio auth',
        'web platform — biometrics unavailable, allow through',
        api: api,
        requestId: requestId,
      );
      _isAuthenticated = true;
      return;
    }

    final canAuth = await _auth.canCheckBiometrics ||
        await _auth.isDeviceSupported();
    if (!canAuth) {
      logInterceptor(
        'bio auth',
        'no biometrics available — allow through',
        api: api,
        requestId: requestId,
      );
      _isAuthenticated = true;
      return;
    }

    try {
      _isAuthenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow PIN fallback
          stickyAuth: true,
        ),
      );
      logInterceptor(
        'bio auth',
        'authenticated = $_isAuthenticated',
        api: api,
        requestId: requestId,
      );
    } on PlatformException catch (e) {
      logInterceptor(
        'bio auth',
        'auth error $e',
        api: api,
        requestId: requestId,
      );
      _isAuthenticated = false;
    }
  }

  void lockApp() => _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
}

// ─────────────────────────────────────────────────────────────────────────────

// lib/core/security/bio_auth_dio_interceptor.dart
// Protects sensitive API calls with biometric prompt.

class BioAuthDioInterceptor extends Interceptor {
  final BioAuthInterceptor _bioAuth = BioAuthInterceptor.instance;

  /// Endpoints that require biometric confirmation before calling
  final List<String> sensitiveEndpoints;

  BioAuthDioInterceptor({
    this.sensitiveEndpoints = const ['/profile/delete'],
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final requestId = options.extra['request_id'] as String? ?? options.path;
    final needsAuth = sensitiveEndpoints.any((e) => options.path.contains(e));
    logInterceptor(
      'bio auth dio',
      'path=${options.path} needsAuth=$needsAuth',
      api: options.path,
      requestId: requestId,
    );

    if (!needsAuth) {
      return handler.next(options);
    }

    await _bioAuth.authenticate(api: options.path, requestId: requestId);

    if (!_bioAuth.isAuthenticated) {
      logInterceptor(
        'bio auth dio',
        'authentication failed — reject request',
        api: options.path,
        requestId: requestId,
      );
      return handler.reject(
        DioException(
          requestOptions: options,
          error: Exception('Biometric authentication failed or cancelled.'),
        ),
      );
    }

    logInterceptor(
      'bio auth dio',
      'authentication passed — proceed',
      api: options.path,
      requestId: requestId,
    );
    return handler.next(options);
  }
}
