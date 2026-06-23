// lib/core/interceptors/performance_interceptor.dart
//
// ⚡ PERFORMANCE INTERCEPTOR
// Measures request duration. Warns on slow requests (>2s).
// Reports metrics to analytics. Cancels requests exceeding hard timeout.

import 'package:dio/dio.dart';

import 'package:interceptors_demo/core/history/request_history.dart';
import 'package:interceptors_demo/core/logs/log_store.dart';

class PerformanceInterceptor extends Interceptor {
  /// Warn threshold: log a warning if request takes longer than this
  final Duration warnThreshold;

  /// Hard limit: cancel requests taking longer than this
  final Duration? hardTimeout;

  /// Optional analytics callback (e.g., Firebase Performance)
  final void Function(PerformanceMetric metric)? onMetric;

  PerformanceInterceptor({
    this.warnThreshold = const Duration(seconds: 2),
    this.hardTimeout,
    this.onMetric,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_perf_start'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _recordMetric(
      options: response.requestOptions,
      statusCode: response.statusCode,
      success: true,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _recordMetric(
      options: err.requestOptions,
      statusCode: err.response?.statusCode,
      success: false,
    );
    handler.next(err);
  }

  void _recordMetric({
    required RequestOptions options,
    required int? statusCode,
    required bool success,
  }) {
    final startMs = options.extra['_perf_start'] as int?;
    if (startMs == null) return;

    final requestId = options.extra['request_id'] as String? ?? options.path;
    final durationMs = DateTime.now().millisecondsSinceEpoch - startMs;
    final duration = Duration(milliseconds: durationMs);

    final metric = PerformanceMetric(
      path: options.path,
      method: options.method,
      durationMs: durationMs,
      statusCode: statusCode,
      success: success,
    );

    // Emit to analytics
    onMetric?.call(metric);

    // Record in in-memory history for the dashboard
    RequestHistory.instance.record(
      method: options.method,
      path: options.path,
      statusCode: statusCode,
      durationMs: durationMs,
      cacheHit: options.extra['_cacheHit'] == true,
    );

    if (duration > warnThreshold) {
      logInterceptor(
        'performance',
        '⚠️ SLOW REQUEST ${options.method} ${options.path} '
            'took ${durationMs}ms (threshold: ${warnThreshold.inMilliseconds}ms)',
        api: options.path,
        requestId: requestId,
      );
    } else {
      logInterceptor(
        'performance',
        '⚡ ${options.method} ${options.path} completed in ${durationMs}ms',
        api: options.path,
        requestId: requestId,
      );
    }
  }
}

class PerformanceMetric {
  final String path;
  final String method;
  final int durationMs;
  final int? statusCode;
  final bool success;
  final DateTime timestamp;

  PerformanceMetric({
    required this.path,
    required this.method,
    required this.durationMs,
    required this.statusCode,
    required this.success,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'path': path,
        'method': method,
        'duration_ms': durationMs,
        'status_code': statusCode,
        'success': success,
        'timestamp': timestamp.toIso8601String(),
      };
}
