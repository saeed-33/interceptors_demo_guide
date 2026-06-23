// lib/core/interceptors/validator_interceptor.dart
//
// ✅ VALIDATOR INTERCEPTOR
// Validates request data before sending.
// Validates response structure before returning to the app.
// Uses schema definitions per-endpoint.

import 'package:dio/dio.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';

typedef ValidationSchema = Map<String, FieldRule>;

class FieldRule {
  final bool required;
  final int? minLength;
  final int? maxLength;
  final String? pattern; // regex
  final String? type; // 'string', 'number', 'email'

  const FieldRule({
    this.required = false,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.type,
  });
}

/// Register schemas per path
final Map<String, ValidationSchema> _requestSchemas = {
  '/auth/login': {
    'email': FieldRule(required: true, type: 'email'),
    'password': FieldRule(required: true, minLength: 8, maxLength: 128),
  },
  '/auth/register': {
    'name': FieldRule(required: true, minLength: 2, maxLength: 50),
    'email': FieldRule(required: true, type: 'email'),
    'password': FieldRule(required: true, minLength: 8),
  },
  '/posts': {
    'title': FieldRule(required: true, minLength: 3, maxLength: 100),
    'body': FieldRule(required: true, minLength: 10),
  },
};

class ValidatorInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = options.extra['request_id'] as String? ?? options.path;
    logInterceptor(
      'validator',
      'validate request ${options.method} ${options.path}',
      api: options.path,
      requestId: requestId,
    );
    final schema = _requestSchemas[options.path];

    if (schema != null && options.data is Map<String, dynamic>) {
      final errors = _validate(options.data as Map<String, dynamic>, schema);
      if (errors.isNotEmpty) {
        logInterceptor(
          'validator',
          'validation failed $errors',
          api: options.path,
          requestId: requestId,
        );
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            error: RequestValidationException(errors),
          ),
        );
      }
    }

    logInterceptor(
      'validator',
      'request valid',
      api: options.path,
      requestId: requestId,
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.extra['request_id'] as String? ??
        response.requestOptions.path;
    logInterceptor(
      'validator',
      'validate response ${response.statusCode} for ${response.requestOptions.path}',
      api: response.requestOptions.path,
      requestId: requestId,
    );
    // Validate response has expected top-level structure
    if (response.data is Map) {
      final data = response.data as Map<String, dynamic>;

      // Our API always returns { success, data } or { success, error }
      if (!data.containsKey('success')) {
        logInterceptor(
          'validator',
          "response missing 'success' field",
          api: response.requestOptions.path,
          requestId: requestId,
        );
        return handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            error: ResponseValidationException(
              'Response missing required "success" field',
            ),
          ),
        );
      }
    }

    logInterceptor(
      'validator',
      'response valid',
      api: response.requestOptions.path,
      requestId: requestId,
    );
    handler.next(response);
  }

  Map<String, String> _validate(
    Map<String, dynamic> data,
    ValidationSchema schema,
  ) {
    final errors = <String, String>{};

    for (final entry in schema.entries) {
      final field = entry.key;
      final rule = entry.value;
      final value = data[field];

      if (rule.required && (value == null || value.toString().isEmpty)) {
        errors[field] = '$field is required';
        continue;
      }

      if (value == null) continue;

      final str = value.toString();

      if (rule.type == 'email' &&
          !RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(str)) {
        errors[field] = '$field must be a valid email address';
      }

      if (rule.minLength != null && str.length < rule.minLength!) {
        errors[field] = '$field must be at least ${rule.minLength} characters';
      }

      if (rule.maxLength != null && str.length > rule.maxLength!) {
        errors[field] = '$field must be at most ${rule.maxLength} characters';
      }

      if (rule.pattern != null && !RegExp(rule.pattern!).hasMatch(str)) {
        errors[field] = '$field format is invalid';
      }
    }

    return errors;
  }
}

class RequestValidationException implements Exception {
  final Map<String, String> errors;
  RequestValidationException(this.errors);

  @override
  String toString() => 'RequestValidationException: $errors';
}

class ResponseValidationException implements Exception {
  final String message;
  ResponseValidationException(this.message);

  @override
  String toString() => 'ResponseValidationException: $message';
}
