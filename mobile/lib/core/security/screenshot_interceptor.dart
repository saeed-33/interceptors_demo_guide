// lib/core/security/screenshot_interceptor.dart
//
// 📵 SCREENSHOT PREVENTION INTERCEPTOR
// Enables FLAG_SECURE on Android (blocks screenshots and screen recording).
// On iOS, uses ScreenProtector to prevent screenshots and hide content in app switcher.
// Can be enabled globally or per-screen.

import 'package:screen_protector/screen_protector.dart';

class ScreenshotInterceptor {
  static final instance = ScreenshotInterceptor._();
  ScreenshotInterceptor._();

  bool _globallyEnabled = false;

  /// Enable screenshot prevention globally (call in main())
  Future<void> enable() async {
    await ScreenProtector.preventScreenshotOn();
    // Hide app content in app switcher (iOS)
    await ScreenProtector.protectDataLeakageWithBlur();
    _globallyEnabled = true;
  }

  /// Disable globally (e.g., for specific public screens)
  Future<void> disable() async {
    await ScreenProtector.preventScreenshotOff();
    _globallyEnabled = false;
  }

  bool get isEnabled => _globallyEnabled;
}

/// Widget wrapper that enables screenshot prevention for a specific screen.
///
/// Usage:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   ScreenshotInterceptor.instance.enable();
/// }
///
/// @override
/// void dispose() {
///   ScreenshotInterceptor.instance.disable();
///   super.dispose();
/// }
/// ```
