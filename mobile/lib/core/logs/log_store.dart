// lib/core/logs/log_store.dart
//
// In-memory store for interceptor log lines.
// Every interceptor prints to the terminal AND writes here so the LogsPage
// can display the same output that appears in the console.

import 'package:flutter/foundation.dart';

class LogStore {
  static final LogStore instance = LogStore._();
  LogStore._();

  final ValueNotifier<List<LogEntry>> notifier = ValueNotifier([]);
  final List<LogEntry> _entries = [];

  static const int maxEntries = 500;

  /// Add a log entry.
  ///
  /// [api] is the request path or logical group the log belongs to
  /// (e.g. `/posts`, `/auth/login`, `startup`).
  ///
  /// [requestId] groups all logs that belong to a single request invocation.
  /// Multiple calls to the same API get separate [requestId]s so each request
  /// appears as its own group in the LogsPage.
  void add(
    String interceptor,
    String message, {
    String api = 'global',
    String requestId = 'global',
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      interceptor: interceptor,
      message: message,
      api: api,
      requestId: requestId,
    );
    _entries.insert(0, entry);
    if (_entries.length > maxEntries) {
      _entries.removeLast();
    }
    notifier.value = List.unmodifiable(_entries);
  }

  void clear() {
    _entries.clear();
    notifier.value = List.unmodifiable(_entries);
  }

  List<LogEntry> get entries => List.unmodifiable(_entries);
}

/// Logs a message to the terminal and to the in-memory [LogStore].
/// Use this from every interceptor so the LogsPage stays in sync with prints.
///
/// [api] groups the log under a request path or logical name in the UI.
/// [requestId] groups all logs for a single request invocation.
void logInterceptor(
  String interceptor,
  String message, {
  String api = 'global',
  String requestId = 'global',
}) {
  final line = '==== $interceptor interceptor : $message';
  print(line);
  LogStore.instance.add(interceptor, message, api: api, requestId: requestId);
}

class LogEntry {
  final DateTime timestamp;
  final String interceptor;
  final String message;

  /// Request path or logical group this log belongs to (e.g. `/posts`, `startup`).
  final String api;

  /// Unique identifier for a single request invocation.
  /// All interceptor logs for one request share the same [requestId].
  final String requestId;

  LogEntry({
    required this.timestamp,
    required this.interceptor,
    required this.message,
    this.api = 'global',
    this.requestId = 'global',
  });
}
