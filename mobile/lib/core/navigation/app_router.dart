import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';

import 'package:interceptors_demo/features/auth/presentation/pages/login_page.dart';
import 'package:interceptors_demo/features/posts/presentation/pages/posts_page.dart';
import 'package:interceptors_demo/features/splash/presentation/pages/splash_page.dart';
import 'package:interceptors_demo/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:interceptors_demo/features/settings/presentation/pages/settings_page.dart';
import 'package:interceptors_demo/features/logs/presentation/pages/logs_page.dart';

class AppRouter {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/login',  builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/posts',
        builder: (_, state) => PostsPage(postId: state.uri.queryParameters['id']),
      ),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
      GoRoute(path: '/settings',  builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/logs',      builder: (_, __) => const LogsPage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Text('Page not found: ${state.uri}',
            style: const TextStyle(color: Colors.white)),
      ),
    ),
  );
}

/// Dio-level interceptor: attaches current screen route to every request
class NavigationInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = options.extra['request_id'] as String? ?? options.path;
    final route = AppRouter.router.routerDelegate.currentConfiguration
        .matches.lastOrNull?.matchedLocation;
    if (route != null) {
      options.headers['X-Screen-Origin'] = route;
    }
    logInterceptor(
      'navigation',
      'attach X-Screen-Origin = ${route ?? 'unknown'} to ${options.path}',
      api: options.path,
      requestId: requestId,
    );
    handler.next(options);
  }
}
