// lib/core/interceptors/soft_delete_interceptor.dart
//
// 🗑️ SOFT DELETE INTERCEPTOR
// Transforms DELETE requests into PATCH requests with { deleted_at: now }.
// Filters out soft-deleted records from GET responses automatically.
// Endpoints can opt out via extra['hardDelete'] = true.

import 'package:dio/dio.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';

class SoftDeleteInterceptor extends Interceptor {
  /// Field name the backend uses for soft deletes
  final String deletedAtField;

  /// Endpoints that should skip soft-delete transformation
  final List<String> hardDeletePaths;

  SoftDeleteInterceptor({
    this.deletedAtField = 'deleted_at',
    this.hardDeletePaths = const [],
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = options.extra['request_id'] as String? ?? options.path;
    final isDelete = options.method.toUpperCase() == 'DELETE';
    final isHardDelete = options.extra['hardDelete'] == true ||
        hardDeletePaths.any((p) => options.path.contains(p));

    if (isDelete && !isHardDelete) {
      // Transform DELETE → PATCH with soft delete payload
      logInterceptor(
        'soft delete',
        'transform DELETE ${options.path} → PATCH',
        api: options.path,
        requestId: requestId,
      );
      options.method = 'PATCH';
      options.data = {
        deletedAtField: DateTime.now().toUtc().toIso8601String(),
        if (options.data is Map) ...(options.data as Map<String, dynamic>),
      };
      options.headers['X-Soft-Delete'] = 'true';
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Filter soft-deleted records out of list responses
    if (response.data is List) {
      response.data = (response.data as List).where((item) {
        if (item is Map<String, dynamic>) {
          return item[deletedAtField] == null;
        }
        return true;
      }).toList();
    }

    // For paginated responses: { data: [...], meta: {...} }
    if (response.data is Map &&
        (response.data as Map).containsKey('data') &&
        response.data['data'] is List) {
      response.data['data'] = (response.data['data'] as List).where((item) {
        if (item is Map<String, dynamic>) {
          return item[deletedAtField] == null;
        }
        return true;
      }).toList();
    }

    handler.next(response);
  }
}
