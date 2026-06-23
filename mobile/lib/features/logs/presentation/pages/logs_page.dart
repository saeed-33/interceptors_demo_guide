import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:interceptors_demo/core/logs/log_store.dart';
import 'package:interceptors_demo/shared/theme/app_theme.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  /// Request IDs/groups that are currently collapsed in the grouped view.
  final Set<String> _collapsed = {};

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  /// Build a flat list of header/entry widgets grouped by [LogEntry.requestId].
  /// Each API invocation gets its own [requestId], so repeated calls to the
  /// same endpoint appear as separate groups.
  /// Groups are ordered by their latest log timestamp (most recent first).
  List<_LogListItem> _buildItems(List<LogEntry> entries) {
    final query = _filter.toLowerCase();
    final filtered = query.isEmpty
        ? entries
        : entries.where((e) {
            return e.api.toLowerCase().contains(query) ||
                e.requestId.toLowerCase().contains(query) ||
                e.interceptor.toLowerCase().contains(query) ||
                e.message.toLowerCase().contains(query);
          }).toList();

    final groups = <String, List<LogEntry>>{};
    for (final entry in filtered) {
      groups.putIfAbsent(entry.requestId, () => []).add(entry);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final aLatest = groups[a]!.first.timestamp;
        final bLatest = groups[b]!.first.timestamp;
        return bLatest.compareTo(aLatest);
      });

    final items = <_LogListItem>[];
    for (final key in sortedKeys) {
      final groupEntries = groups[key]!;
      final collapsed = _collapsed.contains(key);
      final api = groupEntries.first.api;
      items.add(_LogListItem.header(key, api, groupEntries.length, collapsed));
      if (!collapsed) {
        for (final entry in groupEntries) {
          items.add(_LogListItem.entry(entry));
        }
      }
    }
    return items;
  }

  void _toggleGroup(String requestId) {
    setState(() {
      if (_collapsed.contains(requestId)) {
        _collapsed.remove(requestId);
      } else {
        _collapsed.add(requestId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _AppBar(
            onClear: () => LogStore.instance.clear(),
          ),
          Expanded(
            child: Row(
              children: [
                const _Sidebar(currentRoute: 'logs'),
                Expanded(
                  child: Column(
                    children: [
                      // Filter bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _filterController,
                                onChanged: (v) => setState(() => _filter = v.toLowerCase()),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Filter by API, request id, interceptor or message...',
                                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.accent),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ValueListenableBuilder<List<LogEntry>>(
                              valueListenable: LogStore.instance.notifier,
                              builder: (context, entries, _) => Text(
                                '${entries.length} entries',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Grouped log list
                      Expanded(
                        child: ValueListenableBuilder<List<LogEntry>>(
                          valueListenable: LogStore.instance.notifier,
                          builder: (context, entries, _) {
                            final items = _buildItems(entries);

                            if (items.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No logs yet.\nPerform an action to see interceptor output.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: items.length,
                              itemBuilder: (_, i) {
                                final item = items[i];
                                if (item.isHeader) {
                                  return _GroupHeader(
                                    requestId: item.requestId!,
                                    api: item.api!,
                                    count: item.count!,
                                    collapsed: item.collapsed!,
                                    onToggle: () => _toggleGroup(item.requestId!),
                                  );
                                }
                                return _LogRow(entry: item.entry!);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── List Item Model ──────────────────────────────────────────────────────────

class _LogListItem {
  final LogEntry? entry;
  final String? requestId;
  final String? api;
  final int? count;
  final bool? collapsed;
  final bool isHeader;

  _LogListItem.header(this.requestId, this.api, this.count, this.collapsed)
      : entry = null,
        isHeader = true;

  _LogListItem.entry(this.entry)
      : requestId = null,
        api = null,
        count = null,
        collapsed = null,
        isHeader = false;
}

// ─── AppBar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final VoidCallback onClear;
  const _AppBar({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(child: Text('🔗', style: TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 10),
          const Text(
            'Interceptors Demo',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          const Text('/', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          const Text('logs', style: TextStyle(color: AppColors.accent, fontSize: 13)),
          const Spacer(),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.error),
            label: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final String currentRoute;
  const _Sidebar({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SideItem('posts', '📄', 'Posts'),
      _SideItem('dashboard', '⚡', 'Interceptors'),
      _SideItem('settings', '⚙️', 'Settings'),
      _SideItem('logs', '📋', 'Logs'),
    ];

    return Container(
      width: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...items.map((item) {
            final isActive = item.id == currentRoute;
            return Tooltip(
              message: item.label,
              preferBelow: false,
              child: GestureDetector(
                onTap: () {
                  if (item.id == 'posts') context.go('/posts');
                  if (item.id == 'dashboard') context.go('/dashboard');
                  if (item.id == 'settings') context.go('/settings');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.accentDim : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? AppColors.accent.withOpacity(0.4) : Colors.transparent,
                    ),
                  ),
                  child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 18))),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SideItem {
  final String id, emoji, label;
  const _SideItem(this.id, this.emoji, this.label);
}

// ─── Group Header ─────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String requestId;
  final String api;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;

  const _GroupHeader({
    required this.requestId,
    required this.api,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final displayApi = _displayNameForApi(api);
    final shortId = requestId.length > 8 ? requestId.substring(0, 8) : requestId;
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            AnimatedRotation(
              turns: collapsed ? 0 : 0.25,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
            ),
            const SizedBox(width: 8),
            Icon(_iconFor(api), color: AppColors.accent, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayApi,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Courier New',
                    ),
                  ),
                  if (requestId != api)
                    Text(
                      'req: $shortId',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontFamily: 'Courier New',
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayNameForApi(String api) {
    if (api == 'global') return 'Global / Other';
    if (api == 'startup') return 'Startup';
    if (api == 'cache') return 'Cache Actions';
    if (api == 'state') return 'Network State';
    if (!api.startsWith('/')) return api;
    return api;
  }

  IconData _iconFor(String api) {
    switch (api) {
      case 'startup':
        return Icons.power_settings_new;
      case 'cache':
        return Icons.storage;
      case 'state':
        return Icons.swap_horiz;
      case 'global':
        return Icons.public;
      default:
        return api.startsWith('/auth') ? Icons.lock_outline : Icons.api;
    }
  }
}

// ─── Log Row ──────────────────────────────────────────────────────────────────
class _LogRow extends StatelessWidget {
  final LogEntry entry;
  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatTime(entry.timestamp),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'Courier New'),
          ),
          const SizedBox(width: 12),
          Container(
            width: 110,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _colorFor(entry.interceptor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _colorFor(entry.interceptor).withOpacity(0.3)),
            ),
            child: Text(
              entry.interceptor,
              style: TextStyle(
                color: _colorFor(entry.interceptor),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'Courier New',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  Color _colorFor(String interceptor) {
    switch (interceptor) {
      case 'network':
        return AppColors.tagNetwork;
      case 'auth':
        return AppColors.tagAuth;
      case 'cache':
        return AppColors.tagCache;
      case 'encrypt':
      case 'bio auth':
      case 'bio auth dio':
      case 'root detection':
      case 'root detection dio':
        return AppColors.tagSecurity;
      case 'validator':
        return AppColors.success;
      case 'error':
        return AppColors.error;
      case 'performance':
        return AppColors.tagPerf;
      case 'state':
      case 'navigation':
        return AppColors.tagState;
      case 'logger':
        return AppColors.tagLog;
      case 'soft delete':
      case 'update check':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }
}
