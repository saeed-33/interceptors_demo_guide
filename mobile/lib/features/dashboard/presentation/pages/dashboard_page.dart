import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:interceptors_demo/shared/theme/app_theme.dart';
import 'package:interceptors_demo/shared/widgets/shared_widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  final List<_LogEntry> _logs = [];
  final _random = Random();
  late AnimationController _pulseController;
  bool _isRunning = false;
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _errors = 0;
  int _avgMs = 0;
  final List<int> _durations = [];

  final List<_InterceptorStatus> _interceptors = [
    _InterceptorStatus('🌐', 'Network', 'NetworkInterceptor', AppColors.tagNetwork, true),
    _InterceptorStatus('📋', 'Log', 'AppLogInterceptor', AppColors.tagLog, true),
    _InterceptorStatus('💾', 'Cache', 'CacheInterceptor', AppColors.tagCache, true),
    _InterceptorStatus('🗑️', 'Soft Delete', 'SoftDeleteInterceptor', AppColors.warning, true),
    _InterceptorStatus('✅', 'Validator', 'ValidatorInterceptor', AppColors.success, true),
    _InterceptorStatus('🔐', 'Encrypt', 'EncryptInterceptor', AppColors.tagSecurity, false),
    _InterceptorStatus('🔑', 'Auth', 'AuthInterceptor', AppColors.tagAuth, true),
    _InterceptorStatus('⚡', 'Performance', 'PerformanceInterceptor', AppColors.tagPerf, true),
    _InterceptorStatus('🧭', 'Navigation', 'NavigationInterceptor', AppColors.tagState, true),
    _InterceptorStatus('❌', 'Error', 'ErrorInterceptor', AppColors.error, true),
    _InterceptorStatus('🔄', 'Update Check', 'UpdateCheckInterceptor', AppColors.warning, true),
    _InterceptorStatus('🔄', 'State', 'StateInterceptor', AppColors.tagState, true),
    _InterceptorStatus('👆', 'Bio Auth', 'BioAuthInterceptor', AppColors.tagSecurity, false),
    _InterceptorStatus('🔒', 'Root Check', 'RootDetectionInterceptor', AppColors.warning, true),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _generateInitialLogs();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _generateInitialLogs() {
    final methods = ['GET', 'POST', 'PATCH', 'GET', 'GET'];
    final paths = ['/api/posts', '/api/auth/login', '/api/posts/2', '/api/posts/1', '/api/posts'];
    final statuses = [200, 201, 204, 200, 200];

    for (int i = 0; i < 8; i++) {
      final idx = _random.nextInt(methods.length);
      final dur = 40 + _random.nextInt(600);
      _durations.add(dur);
      _logs.insert(0, _LogEntry(
        method: methods[idx],
        path: paths[idx],
        status: statuses[idx],
        durationMs: dur,
        time: DateTime.now().subtract(Duration(seconds: (8 - i) * 12)),
        interceptors: _randomInterceptors(),
        cacheHit: _random.nextBool() && paths[idx].startsWith('/api/posts'),
      ));
    }
    _totalRequests = _logs.length;
    _cacheHits = _logs.where((l) => l.cacheHit).length;
    _errors = _logs.where((l) => l.status >= 400).length;
    _avgMs = _durations.isEmpty ? 0 : _durations.reduce((a, b) => a + b) ~/ _durations.length;
  }

  List<String> _randomInterceptors() {
    final all = ['Network', 'Auth', 'Cache', 'Log', 'Error', 'Performance'];
    all.shuffle(_random);
    return all.take(2 + _random.nextInt(3)).toList();
  }

  Future<void> _simulateRequest() async {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    final methods = ['GET', 'POST', 'GET', 'PATCH', 'DELETE', 'GET'];
    final paths = ['/api/posts', '/api/posts', '/api/posts/3', '/api/posts/1', '/api/posts/2', '/api/auth/me'];
    final statuses = [200, 201, 200, 204, 204, 401];

    final idx = _random.nextInt(methods.length);
    final dur = 30 + _random.nextInt(800);
    final isCacheHit = methods[idx] == 'GET' && _random.nextDouble() > 0.4;
    final status = statuses[idx];

    _durations.add(dur);

    final entry = _LogEntry(
      method: methods[idx],
      path: paths[idx],
      status: status,
      durationMs: dur,
      time: DateTime.now(),
      interceptors: _randomInterceptors(),
      cacheHit: isCacheHit,
    );

    // Add with a small delay to show the animation
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _logs.insert(0, entry);
        if (_logs.length > 20) _logs.removeLast();
        _totalRequests++;
        if (isCacheHit) _cacheHits++;
        if (status >= 400) _errors++;
        _avgMs = _durations.reduce((a, b) => a + b) ~/ _durations.length;
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _DashboardAppBar(isRunning: _isRunning, onSimulate: _simulateRequest),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Left: Interceptor Status Grid ─────────────────────
                _Sidebar(currentRoute: 'dashboard'),

                // ─── Center: Live Log ───────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      // Stats row
                      _StatsRow(
                        total: _totalRequests,
                        cacheHits: _cacheHits,
                        errors: _errors,
                        avgMs: _avgMs,
                      ),
                      // Log
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'LIVE REQUEST LOG', subtitle: 'Last 20 requests'),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: _logs.length,
                                itemBuilder: (_, i) {
                                  final log = _logs[i];
                                  return TweenAnimationBuilder<double>(
                                    key: ValueKey(log.time.millisecondsSinceEpoch),
                                    tween: Tween(begin: i == 0 ? 0.0 : 1.0, end: 1.0),
                                    duration: const Duration(milliseconds: 350),
                                    builder: (_, v, child) => Opacity(
                                      opacity: v,
                                      child: Transform.translate(offset: Offset(0, (1 - v) * -16), child: child),
                                    ),
                                    child: LogTile(
                                      method: log.method,
                                      path: log.path,
                                      statusCode: log.status,
                                      durationMs: log.durationMs,
                                      time: log.time,
                                      badges: [
                                        if (log.cacheHit)
                                          const InterceptorBadge(label: 'CACHE', color: AppColors.tagCache, emoji: '💾'),
                                        if (log.durationMs > 500)
                                          const InterceptorBadge(label: 'SLOW', color: AppColors.warning, emoji: '⚠️'),
                                        if (log.status == 401)
                                          const InterceptorBadge(label: 'REFRESH', color: AppColors.tagAuth, emoji: '🔑'),
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

                // ─── Right: Interceptor Status Panel ───────────────────
                Container(
                  width: 240,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(left: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      const SectionHeader(title: 'INTERCEPTORS', subtitle: 'Click to toggle'),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          itemCount: _interceptors.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 3),
                          itemBuilder: (_, i) {
                            final ic = _interceptors[i];
                            return GestureDetector(
                              onTap: () => setState(() => _interceptors[i] = ic.copyWith(enabled: !ic.enabled)),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: ic.enabled ? ic.color.withOpacity(0.07) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: ic.enabled ? ic.color.withOpacity(0.2) : AppColors.border.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(ic.emoji, style: TextStyle(fontSize: 14, color: ic.enabled ? null : const Color(0x44FFFFFF))),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ic.name,
                                            style: TextStyle(
                                              color: ic.enabled ? ic.color : AppColors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
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
                                          color: ic.enabled ? ic.color : AppColors.textMuted.withOpacity(0.3),
                                          shape: BoxShape.circle,
                                          boxShadow: ic.enabled
                                              ? [BoxShadow(color: ic.color.withOpacity(_pulseController.value * 0.5), blurRadius: 4, spreadRadius: 1)]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                        child: Text(
                          '${_interceptors.where((i) => i.enabled).length}/${_interceptors.length} active',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          textAlign: TextAlign.center,
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

// ─── Dashboard AppBar ─────────────────────────────────────────────────────────
class _DashboardAppBar extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onSimulate;

  const _DashboardAppBar({required this.isRunning, required this.onSimulate});

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
            onPressed: isRunning ? null : onSimulate,
            icon: isRunning
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                : const Icon(Icons.play_arrow, size: 16),
            label: const Text('Simulate Request'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
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
class _LogEntry {
  final String method, path;
  final int status, durationMs;
  final DateTime time;
  final List<String> interceptors;
  final bool cacheHit;

  const _LogEntry({
    required this.method, required this.path, required this.status,
    required this.durationMs, required this.time, required this.interceptors,
    required this.cacheHit,
  });
}

class _InterceptorStatus {
  final String emoji, name, className;
  final Color color;
  final bool enabled;

  const _InterceptorStatus(this.emoji, this.name, this.className, this.color, this.enabled);

  _InterceptorStatus copyWith({bool? enabled}) =>
      _InterceptorStatus(emoji, name, className, color, enabled ?? this.enabled);
}
