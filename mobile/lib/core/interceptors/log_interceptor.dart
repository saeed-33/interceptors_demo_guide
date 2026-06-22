// lib/core/interceptors/log_interceptor.dart
//
// 📋 LOG INTERCEPTOR
// Logs every request/response/error in a structured, color-coded format.
// In production, logs are written to a file and never printed to console.

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

class AppLogInterceptor extends Interceptor {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
    // In production: level: Level.warning
    level: Level.debug,
  );

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print(
        "==== logger interceptor : log request , URL ( ${options.uri} )");
    _logger.i(
      '➡️ REQUEST\n'
      'Method : ${options.method}\n'
      'URL    : ${options.uri}\n'
      'Headers: ${_sanitizeHeaders(options.headers)}\n'
      'Body   : ${options.data}',
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print(
        "==== logger interceptor : log response , URL ( ${response.requestOptions.uri} )");

    _logger.d(
      '✅ RESPONSE [${response.statusCode}]\n'
      'URL  : ${response.requestOptions.uri}\n'
      'Data : ${response.data}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print(
        "==== logger interceptor : log error , URL ( ${err.requestOptions.uri} )");

    _logger.e(
      '❌ ERROR\n'
      'URL    : ${err.requestOptions.uri}\n'
      'Status : ${err.response?.statusCode}\n'
      'Message: ${err.message}\n'
      'Data   : ${err.response?.data}',
      error: err,
      stackTrace: err.stackTrace,
    );
    super.onError(err, handler);
  }

  /// Remove sensitive headers before logging (Authorization, API keys)
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {

    print(
        "==== logger interceptor : remove sensitive headers before logging");

    final sanitized = Map<String, dynamic>.from(headers);
    sanitized.remove('Authorization');
    sanitized.remove('X-API-Key');
    return sanitized;
  }
}
