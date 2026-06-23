// lib/core/interceptors/state_interceptor.dart
//
// 🔄 STATE MANAGEMENT INTERCEPTOR
// Bridges network layer → BLoC state layer.
// Dispatches global loading/error/success events on every request.
// Cubit exposes streams that global UI widgets can listen to.

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';

// ─── Global Network State ────────────────────────────────────────────────────

sealed class NetworkState extends Equatable {
  const NetworkState();
  @override
  List<Object?> get props => [];
}

class NetworkIdle extends NetworkState {
  const NetworkIdle();
}

class NetworkLoading extends NetworkState {
  final String? path;
  const NetworkLoading({this.path});
  @override
  List<Object?> get props => [path];
}

class NetworkSuccess extends NetworkState {
  final String? path;
  const NetworkSuccess({this.path});
  @override
  List<Object?> get props => [path];
}

class NetworkError extends NetworkState {
  final String message;
  final int? statusCode;
  const NetworkError(this.message, {this.statusCode});
  @override
  List<Object?> get props => [message, statusCode];
}

// ─── Global Network Cubit ────────────────────────────────────────────────────

class NetworkCubit extends Cubit<NetworkState> {
  NetworkCubit() : super(const NetworkIdle());

  void setLoading(String? path, {String? requestId}) {
    logInterceptor(
      'state',
      'NetworkLoading for $path',
      api: path ?? 'state',
      requestId: requestId ?? path ?? 'state',
    );
    emit(NetworkLoading(path: path));
  }

  void setSuccess(String? path, {String? requestId}) {
    logInterceptor(
      'state',
      'NetworkSuccess for $path',
      api: path ?? 'state',
      requestId: requestId ?? path ?? 'state',
    );
    emit(NetworkSuccess(path: path));
  }

  void setError(
    String message, {
    int? statusCode,
    String? api,
    String? requestId,
  }) {
    logInterceptor(
      'state',
      'NetworkError ($statusCode) $message',
      api: api ?? 'state',
      requestId: requestId ?? api ?? 'state',
    );
    emit(NetworkError(message, statusCode: statusCode));
  }

  void reset() => emit(const NetworkIdle());
}

// ─── Interceptor ─────────────────────────────────────────────────────────────

class StateInterceptor extends Interceptor {
  final NetworkCubit networkCubit;

  StateInterceptor({required this.networkCubit});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = options.extra['request_id'] as String? ?? options.path;
    // Only update state for requests that opted in
    if (options.extra['trackState'] != false) {
      networkCubit.setLoading(options.path, requestId: requestId);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.extra['request_id'] as String? ??
        response.requestOptions.path;
    if (response.requestOptions.extra['trackState'] != false) {
      networkCubit.setSuccess(response.requestOptions.path, requestId: requestId);

      // Auto-reset to idle after 300ms so the UI can react briefly
      Future.delayed(const Duration(milliseconds: 300), networkCubit.reset);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.extra['request_id'] as String? ??
        err.requestOptions.path;
    if (err.requestOptions.extra['trackState'] != false) {
      final msg = err.error is Exception
          ? err.error.toString().replaceFirst('Exception: ', '')
          : 'Something went wrong';
      networkCubit.setError(
        msg,
        statusCode: err.response?.statusCode,
        api: err.requestOptions.path,
        requestId: requestId,
      );
    }
    handler.next(err);
  }
}
