// lib/core/security/root_detection_interceptor.dart
//
// 🔒 ROOT / JAILBREAK DETECTION INTERCEPTOR
// Detects rooted Android or jailbroken iOS devices.
// On detection: shows a warning, blocks sensitive operations, or exits.
// Also sends a flag in every API request header for server-side awareness.

import 'package:root_check/root_check.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';
import 'package:interceptors_demo/core/navigation/app_router.dart';

class RootDetectionInterceptor {
  static final instance = RootDetectionInterceptor._();
  RootDetectionInterceptor._();

  bool _isRooted = false;

  /// Call at app startup. Checks for root and warns/blocks.
  Future<void> check() async {
    logInterceptor(
      'root detection',
      'check device integrity',
      api: 'startup',
      requestId: 'startup',
    );

    if (kIsWeb) {
      logInterceptor(
        'root detection',
        'web platform — skip root check',
        api: 'startup',
        requestId: 'startup',
      );
      _isRooted = false;
      return;
    }

    try {
      _isRooted = (await RootCheck.isRooted) ?? false;
      logInterceptor(
        'root detection',
        'rooted = $_isRooted',
        api: 'startup',
        requestId: 'startup',
      );

      if (_isRooted) {
        // Delay until first frame is rendered
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showWarningDialog();
        });
      }
    } catch (_) {
      // Root check failed — treat as not rooted (avoid false positives)
      logInterceptor(
        'root detection',
        'check failed — assume not rooted',
        api: 'startup',
        requestId: 'startup',
      );
      _isRooted = false;
    }
  }

  bool get isRooted => _isRooted;

  void _showWarningDialog() {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('Security Warning'),
        ]),
        content: const Text(
          'This device appears to be rooted or jailbroken.\n\n'
          'For your security, some features may not be available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Dio interceptor: adds X-Device-Rooted header so backend can log/block.
class RootDetectionDioInterceptor extends Interceptor {
  final RootDetectionInterceptor _detector = RootDetectionInterceptor.instance;

  /// If true, requests from rooted devices are blocked entirely
  final bool blockRooted;

  RootDetectionDioInterceptor({this.blockRooted = false});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = options.extra['request_id'] as String? ?? options.path;
    final rootedFlag = _detector.isRooted.toString();
    options.headers['X-Device-Rooted'] = rootedFlag;
    logInterceptor(
      'root detection dio',
      'set X-Device-Rooted = $rootedFlag',
      api: options.path,
      requestId: requestId,
    );

    if (blockRooted && _detector.isRooted) {
      logInterceptor(
        'root detection dio',
        'blocking rooted device',
        api: options.path,
        requestId: requestId,
      );
      return handler.reject(
        DioException(
          requestOptions: options,
          error: Exception(
            'Access denied: rooted/jailbroken devices are not allowed.',
          ),
        ),
      );
    }

    handler.next(options);
  }
}
