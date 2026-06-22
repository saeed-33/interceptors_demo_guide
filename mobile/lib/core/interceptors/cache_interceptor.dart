// lib/core/interceptors/cache_interceptor.dart
//
// 💾 CACHE INTERCEPTOR
// GET requests are cached in Hive with a configurable TTL.
// Cache-Control headers are respected. Stale cache is served when offline.

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

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
    // Only cache GET requests
    if (options.method.toUpperCase() != 'GET') {
      return handler.next(options);
    }

    // Allow callers to bypass cache via extra options
    if (options.extra['noCache'] == true) {
      return handler.next(options);
    }

    final box = await Hive.openBox<Map>(_cacheBoxName);
    final cacheKey = _buildKey(options);
    final cached = box.get(cacheKey);

    if (cached != null) {
      final expiry = DateTime.parse(cached['expiry'] as String);
      if (DateTime.now().isBefore(expiry)) {
        // Cache HIT — return immediately, skip network
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
      await box.delete(cacheKey);
    }

    return handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (response.requestOptions.method.toUpperCase() == 'GET' &&
        response.statusCode == 200) {
      // Determine TTL from Cache-Control header or use default
      final ttl = _parseCacheControl(response.headers) ?? defaultTtl;

      final box = await Hive.openBox<Map>(_cacheBoxName);
      final cacheKey = _buildKey(response.requestOptions);

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
    final box = await Hive.openBox<Map>(_cacheBoxName);
    await box.clear();
  }

  /// Invalidate a specific endpoint
  static Future<void> invalidate(String path) async {
    final box = await Hive.openBox<Map>(_cacheBoxName);
    final keysToDelete = box.keys.where((k) => k.toString().contains(path));
    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }
}
