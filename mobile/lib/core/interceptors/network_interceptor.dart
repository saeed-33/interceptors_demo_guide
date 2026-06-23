// lib/core/interceptors/network_interceptor.dart
//
// 🌐 NETWORK CONNECTION INTERCEPTOR
// Checks internet connectivity before every request.
// Throws a typed NetworkException if offline.

import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';

class NetworkInterceptor extends Interceptor {
  final Connectivity _connectivity;

  NetworkInterceptor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Generate a correlation ID at the very start of the chain so every
    // interceptor can group its logs under a single request invocation.
    final requestId = const Uuid().v4();
    options.extra['request_id'] = requestId;

    logInterceptor(
      'network',
      'check connectivity before ${options.method} ${options.path}',
      api: options.path,
      requestId: requestId,
    );

    if (kIsWeb) {
      logInterceptor(
        'network',
        'running on web — assume online',
        api: options.path,
        requestId: requestId,
      );
      return handler.next(options);
    }

    final result = await _connectivity.checkConnectivity();

    // connectivity_plus v5 returns a single ConnectivityResult (not a List)
    final isConnected = result != ConnectivityResult.none;

    if (!isConnected) {
      logInterceptor(
        'network',
        'offline — reject request',
        api: options.path,
        requestId: requestId,
      );
      // Reject request with a typed error — never silently fail
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: NetworkException('No internet connection. Please check your network settings.'),
        ),
      );
    }

    logInterceptor(
      'network',
      'online ($result) — proceed',
      api: options.path,
      requestId: requestId,
    );
    return handler.next(options);
  }
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
