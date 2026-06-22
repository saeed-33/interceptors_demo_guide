// lib/core/interceptors/network_interceptor.dart
//
// 🌐 NETWORK CONNECTION INTERCEPTOR
// Checks internet connectivity before every request.
// Throws a typed NetworkException if offline.

import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInterceptor extends Interceptor {
  final Connectivity _connectivity;

  NetworkInterceptor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final result = await _connectivity.checkConnectivity();

    // connectivity_plus v4 returns a single ConnectivityResult (not a List)
    final isConnected = result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet;

    if (!isConnected) {
      // Reject request with a typed error — never silently fail
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: NetworkException('No internet connection. Please check your network settings.'),
        ),
      );
    }

    return handler.next(options);
  }
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
