// lib/core/interceptors/validator_interceptor.dart
//
// ✅ VALIDATOR INTERCEPTOR
// Validates request data before sending.
// Validates response structure before returning to the app.
// Uses schema definitions per-endpoint.

import 'package:dio/dio.dart';

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
    final schema = _requestSchemas[options.path];

    if (schema != null && options.data is Map<String, dynamic>) {
      final errors = _validate(options.data as Map<String, dynamic>, schema);
      if (errors.isNotEmpty) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            error: RequestValidationException(errors),
          ),
        );
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Validate response has expected top-level structure
    if (response.data is Map) {
      final data = response.data as Map<String, dynamic>;

      // Our API always returns { success, data } or { success, error }
      if (!data.containsKey('success')) {
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
