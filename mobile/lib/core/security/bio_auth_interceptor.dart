// lib/core/security/bio_auth_interceptor.dart
//
// 🔐 BIOMETRIC AUTH INTERCEPTOR
// Forces biometric authentication when app returns from background.
// Can also protect specific API calls (e.g., payment, profile change).

import 'package:local_auth/local_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class BioAuthInterceptor {
  static final instance = BioAuthInterceptor._();
  BioAuthInterceptor._();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticated = false;

  /// Call when app resumes from background
  Future<void> authenticate() async {
    final canAuth = await _auth.canCheckBiometrics ||
        await _auth.isDeviceSupported();
    if (!canAuth) {
      _isAuthenticated = true; // No biometrics available, allow through
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
    } on PlatformException {
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
    this.sensitiveEndpoints = const ['/payments', '/profile/delete'],
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final needsAuth = sensitiveEndpoints.any((e) => options.path.contains(e));

    if (!needsAuth) {
      return handler.next(options);
    }

    await _bioAuth.authenticate();

    if (!_bioAuth.isAuthenticated) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: Exception('Biometric authentication failed or cancelled.'),
        ),
      );
    }

    return handler.next(options);
  }
}
