// lib/core/dependencies/app_dependencies.dart
//
// Simple singleton that owns the single Dio client and NetworkCubit used
// throughout the app. In a larger project this would be GetIt / injectable.

import 'package:dio/dio.dart';

import 'package:interceptors_demo/core/interceptors/state_interceptor.dart';
import 'package:interceptors_demo/core/network/dio_client.dart';
import 'package:interceptors_demo/core/security/root_detection_interceptor.dart';

class AppDependencies {
  static final AppDependencies _instance = AppDependencies._internal();
  static AppDependencies get instance => _instance;

  late final NetworkCubit networkCubit;
  late final Dio dio;

  AppDependencies._internal() {
    networkCubit = NetworkCubit();
    dio = DioClient.create(networkCubit: networkCubit);
  }

  static Future<void> initialize() async {
    await RootDetectionInterceptor.instance.check();
  }
}
