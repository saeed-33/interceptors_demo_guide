// lib/core/interceptors/error_interceptor.dart
//
// ❌ ERROR HANDLING INTERCEPTOR
// Transforms raw DioException into typed AppException objects.
// Handles: server errors, timeouts, cancelled requests, parse errors.

import 'package:dio/dio.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';

/// Sealed class representing all possible API failures
sealed class AppException implements Exception {
  final String message;
  final int? statusCode;
  const AppException(this.message, {this.statusCode});
}

class NetworkException extends AppException {
  const NetworkException(super.message) : super(statusCode: null);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException() : super('Session expired. Please log in again.', statusCode: 401);
}

class ForbiddenException extends AppException {
  const ForbiddenException() : super('You do not have permission to perform this action.', statusCode: 403);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message) : super(statusCode: 404);
}

class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;
  const ValidationException(super.message, {this.fieldErrors}) : super(statusCode: 422);
}

class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

class TimeoutException extends AppException {
  const TimeoutException() : super('Request timed out. Please try again.');
}

class CancelledException extends AppException {
  const CancelledException() : super('Request was cancelled.');
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.extra['request_id'] as String? ??
        err.requestOptions.path;
    final appException = _mapException(err);
    logInterceptor(
      'error',
      '${err.requestOptions.method} ${err.requestOptions.path} → ${appException.runtimeType}: ${appException.message}',
      api: err.requestOptions.path,
      requestId: requestId,
    );
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: appException, // Typed error accessible via err.error
      ),
    );
  }

  AppException _mapException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();

      case DioExceptionType.cancel:
        return const CancelledException();

      case DioExceptionType.connectionError:
        if (err.error is NetworkException) return err.error as NetworkException;
        return const NetworkException('Unable to connect. Check your connection.');

      case DioExceptionType.badResponse:
        return _mapStatusCode(err);

      default:
        return ServerException(err.message ?? 'An unexpected error occurred.');
    }
  }

  AppException _mapStatusCode(DioException err) {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;
    final serverMessage = data is Map ? data['message'] as String? : null;

    switch (statusCode) {
      case 400:
        return ServerException(serverMessage ?? 'Bad request.', statusCode: 400);
      case 401:
        return const UnauthorizedException();
      case 403:
        return const ForbiddenException();
      case 404:
        return NotFoundException(serverMessage ?? 'Resource not found.');
      case 422:
        final fieldErrors = data is Map
            ? (data['errors'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, List<String>.from(v as List)),
              )
            : null;
        return ValidationException(
          serverMessage ?? 'Validation failed.',
          fieldErrors: fieldErrors,
        );
      case 500:
      case 502:
      case 503:
        return ServerException(
          serverMessage ?? 'Server error. Please try again later.',
          statusCode: statusCode,
        );
      default:
        return ServerException('HTTP $statusCode: ${serverMessage ?? 'Unknown error'}');
    }
  }
}
