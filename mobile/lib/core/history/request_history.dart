// lib/core/history/request_history.dart
//
// In-memory history of recent network requests used by the Dashboard UI.
// In production this would be a persistent analytics/event store.

import 'package:flutter/foundation.dart';

class RequestHistory {
  static final RequestHistory instance = RequestHistory._();
  RequestHistory._();

  final List<HistoryEntry> _entries = [];
  final ValueNotifier<List<HistoryEntry>> notifier = ValueNotifier([]);

  void record({
    required String method,
    required String path,
    required int? statusCode,
    required int durationMs,
    bool cacheHit = false,
  }) {
    final entry = HistoryEntry(
      method: method,
      path: path,
      statusCode: statusCode,
      durationMs: durationMs,
      timestamp: DateTime.now(),
      cacheHit: cacheHit,
    );
    _entries.insert(0, entry);
    if (_entries.length > 50) _entries.removeLast();
    notifier.value = List.unmodifiable(_entries);
  }

  List<HistoryEntry> get entries => List.unmodifiable(_entries);
}

class HistoryEntry {
  final String method;
  final String path;
  final int? statusCode;
  final int durationMs;
  final DateTime timestamp;
  final bool cacheHit;

  HistoryEntry({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    required this.timestamp,
    this.cacheHit = false,
  });
}
