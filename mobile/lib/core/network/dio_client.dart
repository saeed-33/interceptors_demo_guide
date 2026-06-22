// lib/core/network/dio_client.dart
//
// Central Dio client that registers all interceptors in the correct order.
// ORDER MATTERS — interceptors run top-to-bottom on request, bottom-to-top on response/error.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../interceptors/network_interceptor.dart';
import '../interceptors/log_interceptor.dart';
import '../interceptors/cache_interceptor.dart';
import '../interceptors/auth_interceptor.dart';
import '../interceptors/error_interceptor.dart';
import '../interceptors/encrypt_interceptor.dart';
import '../interceptors/performance_interceptor.dart';
import '../interceptors/validator_interceptor.dart';
import '../interceptors/soft_delete_interceptor.dart';
import '../interceptors/update_check_interceptor.dart';
import '../interceptors/state_interceptor.dart';
import '../navigation/app_router.dart';
import '../security/root_detection_interceptor.dart';
import '../security/bio_auth_interceptor.dart';

class DioClient {
  static Dio create({
    required NetworkCubit networkCubit,
    String baseUrl = 'http://localhost:3000/api',
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // ─── Request interceptors (top = runs first) ──────────────────────────
    dio.interceptors.addAll([
      // 1. 🌐 Check network connectivity first — abort immediately if offline
      NetworkInterceptor(),

      // 2. 🔒 Root detection — flag/block rooted devices
      RootDetectionDioInterceptor(blockRooted: false),

      // 3. 🔐 Bio Auth — require biometrics for sensitive endpoints
      BioAuthDioInterceptor(
        sensitiveEndpoints: ['/payments', '/profile/delete'],
      ),

      // 4. ✅ Validate request data before sending
      ValidatorInterceptor(),

      // 5. 💾 Cache — serve cached GET responses before hitting network
      CacheInterceptor(defaultTtl: const Duration(minutes: 5)),

      // 6. 🔑 Auth — attach Bearer token, handle 401 refresh
      AuthInterceptor(
        dio: dio,
        secureStorage: const FlutterSecureStorage(),
      ),

      // 7. 🔐 Encrypt — encrypt body for sensitive endpoints
      EncryptInterceptor(),

      // 8. 🧭 Navigation — attach current screen name to requests
      NavigationInterceptor(),

      // 9. 🗑️ Soft Delete — transform DELETE → PATCH
      SoftDeleteInterceptor(),

      // 10. 🔄 State — update global loading/error/success state
      StateInterceptor(networkCubit: networkCubit),

      // 11. ⚡ Performance — measure and log request duration
      PerformanceInterceptor(
        warnThreshold: const Duration(seconds: 2),
        onMetric: (metric) {
          // In production: FirebasePerformance.startTrace(metric.path)
        },
      ),

      // 12. ❌ Error — transform Dio errors into typed AppExceptions
      ErrorInterceptor(),

      // 13. 🔄 Update Check — check version headers on responses
      UpdateCheckInterceptor(),

      // 14. 📋 Log — log everything (keep last so it sees final state)
      AppLogInterceptor(),
    ]);

    return dio;
  }
}
