// lib/core/interceptors/update_check_interceptor.dart
//
// 🔄 UPDATE CHECK INTERCEPTOR
// Reads X-App-Min-Version header from every response.
// If current app version is below the minimum, shows a force-update dialog.
// Supports optional (soft) updates via X-App-Latest-Version header.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';
import 'package:interceptors_demo/core/navigation/app_router.dart';

class UpdateCheckInterceptor extends Interceptor {
  bool _updateDialogShown = false;

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final requestId = response.requestOptions.extra['request_id'] as String? ??
        response.requestOptions.path;
    final minVersion = response.headers.value('X-App-Min-Version');
    final latestVersion = response.headers.value('X-App-Latest-Version');

    logInterceptor(
      'update check',
      'min=$minVersion latest=$latestVersion',
      api: response.requestOptions.path,
      requestId: requestId,
    );

    if (minVersion != null || latestVersion != null) {
      final info = await PackageInfo.fromPlatform();
      final current = _parseVersion(info.version);
      logInterceptor(
        'update check',
        'current=${info.version}',
        api: response.requestOptions.path,
        requestId: requestId,
      );

      if (minVersion != null) {
        final min = _parseVersion(minVersion);
        if (_isOlderThan(current, min) && !_updateDialogShown) {
          logInterceptor(
            'update check',
            'force update required',
            api: response.requestOptions.path,
            requestId: requestId,
          );
          _updateDialogShown = true;
          _showForceUpdateDialog();
        }
      } else if (latestVersion != null) {
        final latest = _parseVersion(latestVersion);
        if (_isOlderThan(current, latest) && !_updateDialogShown) {
          logInterceptor(
            'update check',
            'soft update available',
            api: response.requestOptions.path,
            requestId: requestId,
          );
          _updateDialogShown = true;
          _showSoftUpdateDialog(latestVersion);
        }
      }
    }

    handler.next(response);
  }

  void _showForceUpdateDialog() {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Force update — cannot dismiss
      builder: (_) => AlertDialog(
        title: const Text('Update Required'),
        content: const Text(
          'A critical update is available. Please update the app to continue.',
        ),
        actions: [
          TextButton(
            onPressed: _openStore,
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _showSoftUpdateDialog(String latestVersion) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Available'),
        content: Text('Version $latestVersion is available with new features.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDialogShown = false; // Allow re-prompt next session
            },
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: _openStore,
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _openStore() {
    // In production: use url_launcher to open App Store / Play Store
    // launch('https://apps.apple.com/app/...');
  }

  List<int> _parseVersion(String version) {
    return version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  bool _isOlderThan(List<int> current, List<int> other) {
    for (var i = 0; i < 3; i++) {
      final c = i < current.length ? current[i] : 0;
      final o = i < other.length ? other[i] : 0;
      if (c < o) return true;
      if (c > o) return false;
    }
    return false;
  }
}
