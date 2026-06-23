// lib/core/interceptors/log_interceptor.dart
//
// 📋 LOG INTERCEPTOR
// Logs every request/response/error in a structured, color-coded format.
// In production, logs are written to a file and never printed to console.

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';

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
    final requestId = options.extra['request_id'] as String? ?? options.path;
    final msg = 'log REQUEST ${options.method} ${options.path}';
    print('==== logger interceptor : $msg');
    LogStore.instance.add(
      'logger',
      msg,
      api: options.path,
      requestId: requestId,
    );
    _logger.i(
      '➡️ REQUEST\n'
      'Method : ${options.method}\n'
      'URL    : ${options.uri}\n'
      'Headers: ${_sanitizeHeaders(options.headers, api: options.path, requestId: requestId)}\n'
      'Body   : ${options.data}',
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.extra['request_id'] as String? ??
        response.requestOptions.path;
    final msg = 'log RESPONSE ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}';
    print('==== logger interceptor : $msg');
    LogStore.instance.add(
      'logger',
      msg,
      api: response.requestOptions.path,
      requestId: requestId,
    );

    _logger.d(
      '✅ RESPONSE [${response.statusCode}]\n'
      'URL  : ${response.requestOptions.uri}\n'
      'Data : ${response.data}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.extra['request_id'] as String? ??
        err.requestOptions.path;
    final msg = 'log ERROR ${err.response?.statusCode} ${err.requestOptions.method} ${err.requestOptions.path}';
    print('==== logger interceptor : $msg');
    LogStore.instance.add(
      'logger',
      msg,
      api: err.requestOptions.path,
      requestId: requestId,
    );

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
  Map<String, dynamic> _sanitizeHeaders(
    Map<String, dynamic> headers, {
    required String api,
    required String requestId,
  }) {
    const msg = 'remove sensitive headers before logging';
    print('==== logger interceptor : $msg');
    LogStore.instance.add(
      'logger',
      msg,
      api: api,
      requestId: requestId,
    );

    final sanitized = Map<String, dynamic>.from(headers);
    sanitized.remove('Authorization');
    sanitized.remove('X-API-Key');
    return sanitized;
  }
}
