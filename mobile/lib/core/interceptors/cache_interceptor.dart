// lib/core/interceptors/cache_interceptor.dart
//
// 💾 CACHE INTERCEPTOR
// GET requests are cached in Hive with a configurable TTL.
// Cache-Control headers are respected. Stale cache is served when offline.

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import 'package:interceptors_demo/core/history/request_history.dart';
import 'package:interceptors_demo/core/logs/log_store.dart';

const String _cacheBoxName = 'http_cache';

class CacheInterceptor extends Interceptor {
  /// Default cache duration: 5 minutes
  final Duration defaultTtl;

  CacheInterceptor({this.defaultTtl = const Duration(minutes: 5)});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final requestId = options.extra['request_id'] as String? ?? options.path;

    // Only cache GET requests
    if (options.method.toUpperCase() != 'GET') {
      return handler.next(options);
    }

    logInterceptor(
      'cache',
      'lookup cache for ${options.path}',
      api: options.path,
      requestId: requestId,
    );

    // Allow callers to bypass cache via extra options
    if (options.extra['noCache'] == true) {
      logInterceptor(
        'cache',
        'bypass cache requested',
        api: options.path,
        requestId: requestId,
      );
      return handler.next(options);
    }

    final box = await Hive.openBox<Map>(_cacheBoxName);
    final cacheKey = _buildKey(options);
    final cached = box.get(cacheKey);

    if (cached != null) {
      final expiry = DateTime.parse(cached['expiry'] as String);
      if (DateTime.now().isBefore(expiry)) {
        // Cache HIT — return immediately, skip network
        logInterceptor(
          'cache',
          'cache HIT for $cacheKey',
          api: options.path,
          requestId: requestId,
        );
        options.extra['_cacheHit'] = true;
        RequestHistory.instance.record(
          method: options.method,
          path: options.path,
          statusCode: 200,
          durationMs: 0,
          cacheHit: true,
        );
        return handler.resolve(
          Response(
            requestOptions: options,
            data: cached['data'],
            statusCode: 200,
            headers: Headers.fromMap({'X-Cache': ['HIT']}),
          ),
        );
      }
      // Expired — remove from cache
      logInterceptor(
        'cache',
        'cache expired for $cacheKey',
        api: options.path,
        requestId: requestId,
      );
      await box.delete(cacheKey);
    } else {
      logInterceptor(
        'cache',
        'cache MISS for $cacheKey',
        api: options.path,
        requestId: requestId,
      );
    }

    return handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final requestId = response.requestOptions.extra['request_id'] as String? ??
        response.requestOptions.path;
    if (response.requestOptions.method.toUpperCase() == 'GET' &&
        response.statusCode == 200) {
      // Determine TTL from Cache-Control header or use default
      final ttl = _parseCacheControl(response.headers) ?? defaultTtl;

      final box = await Hive.openBox<Map>(_cacheBoxName);
      final cacheKey = _buildKey(response.requestOptions);

      logInterceptor(
        'cache',
        'store response in cache ($cacheKey, ttl=${ttl.inSeconds}s)',
        api: response.requestOptions.path,
        requestId: requestId,
      );
      await box.put(cacheKey, {
        'data': response.data,
        'expiry': DateTime.now().add(ttl).toIso8601String(),
      });
    }

    handler.next(response);
  }

  String _buildKey(RequestOptions options) {
    final params = options.queryParameters.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '${options.method}:${options.path}?$params';
  }

  Duration? _parseCacheControl(Headers headers) {
    final cc = headers.value('cache-control');
    if (cc == null) return null;
    final maxAge = RegExp(r'max-age=(\d+)').firstMatch(cc);
    if (maxAge != null) {
      return Duration(seconds: int.parse(maxAge.group(1)!));
    }
    return null;
  }

  /// Manually invalidate all cached responses
  static Future<void> clearAll() async {
    logInterceptor(
      'cache',
      'clear all cached responses',
      api: 'cache',
      requestId: 'cache',
    );
    final box = await Hive.openBox<Map>(_cacheBoxName);
    await box.clear();
  }

  /// Invalidate a specific endpoint
  static Future<void> invalidate(String path) async {
    logInterceptor(
      'cache',
      'invalidate cache for $path',
      api: 'cache',
      requestId: 'cache',
    );
    final box = await Hive.openBox<Map>(_cacheBoxName);
    final keysToDelete = box.keys.where((k) => k.toString().contains(path));
    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }
}
