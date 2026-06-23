import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:interceptors_demo/core/dependencies/app_dependencies.dart';
import 'package:interceptors_demo/core/history/request_history.dart';
import 'package:interceptors_demo/core/storage/token_storage.dart';
import 'package:interceptors_demo/shared/theme/app_theme.dart';
import 'package:interceptors_demo/shared/widgets/shared_widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isRunning = false;

  final List<_InterceptorInfo> _interceptors = [
    _InterceptorInfo('🌐', 'Network', 'NetworkInterceptor', AppColors.tagNetwork),
    _InterceptorInfo('📋', 'Log', 'AppLogInterceptor', AppColors.tagLog),
    _InterceptorInfo('💾', 'Cache', 'CacheInterceptor', AppColors.tagCache),
    _InterceptorInfo('🗑️', 'Soft Delete', 'SoftDeleteInterceptor', AppColors.warning),
    _InterceptorInfo('✅', 'Validator', 'ValidatorInterceptor', AppColors.success),
    _InterceptorInfo('🔐', 'Encrypt', 'EncryptInterceptor', AppColors.tagSecurity),
    _InterceptorInfo('🔑', 'Auth', 'AuthInterceptor', AppColors.tagAuth),
    _InterceptorInfo('⚡', 'Performance', 'PerformanceInterceptor', AppColors.tagPerf),
    _InterceptorInfo('🧭', 'Navigation', 'NavigationInterceptor', AppColors.tagState),
    _InterceptorInfo('❌', 'Error', 'ErrorInterceptor', AppColors.error),
    _InterceptorInfo('🔄', 'Update Check', 'UpdateCheckInterceptor', AppColors.warning),
    _InterceptorInfo('🔄', 'State', 'StateInterceptor', AppColors.tagState),
    _InterceptorInfo('👆', 'Bio Auth', 'BioAuthDioInterceptor', AppColors.tagSecurity),
    _InterceptorInfo('🔒', 'Root Check', 'RootDetectionDioInterceptor', AppColors.warning),
  ];

  final Dio _dio = AppDependencies.instance.dio;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _triggerBioAuthRequest() async {
    setState(() => _isRunning = true);
    try {
      await _dio.post('/auth/profile/delete');
    } on DioException catch (e) {
      // Expected on web or if auth cancelled; show a snackbar for visibility.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bio-auth demo: ${e.error?.toString() ?? e.message ?? 'request completed'}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _logout() async {
    await TokenStorage.create().deleteAll();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _DashboardAppBar(
            isRunning: _isRunning,
            onBioAuth: _triggerBioAuthRequest,
            onLogout: _logout,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Left: Interceptor List ────────────────────────────
                _Sidebar(currentRoute: 'dashboard'),

                // ─── Center: Live Log ───────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      // Stats row
                      ValueListenableBuilder<List<HistoryEntry>>(
                        valueListenable: RequestHistory.instance.notifier,
                        builder: (context, entries, _) => _StatsRow(
                          total: entries.length,
                          cacheHits: entries.where((l) => l.cacheHit).length,
                          errors: entries.where((l) => (l.statusCode ?? 0) >= 400).length,
                          avgMs: _avg(entries),
                        ),
                      ),
                      // Log
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'LIVE REQUEST LOG', subtitle: 'Last 50 real requests'),
                            Expanded(
                              child: ValueListenableBuilder<List<HistoryEntry>>(
                                valueListenable: RequestHistory.instance.notifier,
                                builder: (context, entries, _) {
                                  if (entries.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'No requests yet.\nNavigate to Posts or trigger an action.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    itemCount: entries.length,
                                    itemBuilder: (_, i) {
                                      final log = entries[i];
                                      return TweenAnimationBuilder<double>(
                                        key: ValueKey(log.timestamp.millisecondsSinceEpoch),
                                        tween: Tween(begin: i == 0 ? 0.0 : 1.0, end: 1.0),
                                        duration: const Duration(milliseconds: 350),
                                        builder: (_, v, child) => Opacity(
                                          opacity: v,
                                          child: Transform.translate(offset: Offset(0, (1 - v) * -16), child: child),
                                        ),
                                        child: LogTile(
                                          method: log.method,
                                          path: log.path,
                                          statusCode: log.statusCode ?? 0,
                                          durationMs: log.durationMs,
                                          time: log.timestamp,
                                          badges: [
                                            if (log.cacheHit)
                                              const InterceptorBadge(label: 'CACHE', color: AppColors.tagCache, emoji: '💾'),
                                            if (log.durationMs > 500)
                                              const InterceptorBadge(label: 'SLOW', color: AppColors.warning, emoji: '⚠️'),
                                            if ((log.statusCode ?? 0) >= 400)
                                              const InterceptorBadge(label: 'ERROR', color: AppColors.error, emoji: '❌'),
                                          ],
                                        ),
                                      );
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

                // ─── Right: Interceptor Info Panel ───────────────────
                Container(
                  width: 240,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(left: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      const SectionHeader(title: 'INTERCEPTORS', subtitle: 'Active chain'),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          itemCount: _interceptors.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 3),
                          itemBuilder: (_, i) {
                            final ic = _interceptors[i];
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: ic.color.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ic.color.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Text(ic.emoji, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ic.name,
                                          style: TextStyle(color: ic.color, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          ic.className,
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (_, __) => Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: ic.color,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: ic.color.withOpacity(_pulseController.value * 0.5), blurRadius: 4, spreadRadius: 1)],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

  int _avg(List<HistoryEntry> entries) {
    if (entries.isEmpty) return 0;
    final durations = entries.where((e) => !e.cacheHit).map((e) => e.durationMs).toList();
    if (durations.isEmpty) return 0;
    return durations.reduce((a, b) => a + b) ~/ durations.length;
  }
}

// ─── Dashboard AppBar ─────────────────────────────────────────────────────────
class _DashboardAppBar extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onBioAuth;
  final VoidCallback onLogout;

  const _DashboardAppBar({required this.isRunning, required this.onBioAuth, required this.onLogout});

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
            width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.accentDim, borderRadius: BorderRadius.circular(6)),
            child: const Center(child: Text('🔗', style: TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 10),
          const Text('Interceptors Demo', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Text('/', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          const Text('dashboard', style: TextStyle(color: AppColors.accent, fontSize: 13)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => context.go('/posts'),
            icon: const Icon(Icons.arrow_back, size: 14, color: AppColors.textSecondary),
            label: const Text('Posts', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isRunning ? null : onBioAuth,
            icon: isRunning
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                : const Icon(Icons.fingerprint, size: 16),
            label: const Text('Bio-Auth Request'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 14, color: AppColors.error),
            label: const Text('Logout', style: TextStyle(color: AppColors.error, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total, cacheHits, errors, avgMs;
  const _StatsRow({required this.total, required this.cacheHits, required this.errors, required this.avgMs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          _Stat(label: 'REQUESTS', value: '$total', color: AppColors.accent),
          _Stat(
            label: 'CACHE HIT RATE',
            value: total == 0 ? '—' : '${((cacheHits / total) * 100).toStringAsFixed(0)}%',
            color: AppColors.tagCache,
          ),
          _Stat(label: 'ERRORS', value: '$errors', color: errors > 0 ? AppColors.error : AppColors.success),
          _Stat(
            label: 'AVG LATENCY',
            value: '${avgMs}ms',
            color: avgMs > 300 ? AppColors.warning : AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Sidebar (reused) ─────────────────────────────────────────────────────────
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
              child: GestureDetector(
                onTap: () {
                  if (item.id == 'posts') context.go('/posts');
                  if (item.id == 'settings') context.go('/settings');
                  if (item.id == 'logs') context.go('/logs');
                },
                child: Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.accentDim : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isActive ? AppColors.accent.withOpacity(0.4) : Colors.transparent),
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

// ─── Models ───────────────────────────────────────────────────────────────────
class _InterceptorInfo {
  final String emoji, name, className;
  final Color color;

  const _InterceptorInfo(this.emoji, this.name, this.className, this.color);
}
