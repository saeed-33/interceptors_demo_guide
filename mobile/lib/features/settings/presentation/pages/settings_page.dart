import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:interceptors_demo/core/interceptors/cache_interceptor.dart';
import 'package:interceptors_demo/core/storage/token_storage.dart';
import 'package:interceptors_demo/shared/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ─── Interceptor documentation (no toggles) ─────────────────────────────────
  final List<_InterceptorSetting> _interceptors = [
    _InterceptorSetting(
      emoji: '🌐',
      name: 'Network Interceptor',
      className: 'NetworkInterceptor',
      description: 'Checks internet connectivity before every request. Aborts with a typed NetworkException when offline.',
      color: AppColors.tagNetwork,
    ),
    _InterceptorSetting(
      emoji: '📋',
      name: 'Log Interceptor',
      className: 'AppLogInterceptor',
      description: 'Logs every request, response and error in a structured, color-coded format. Sanitizes Authorization headers.',
      color: AppColors.tagLog,
    ),
    _InterceptorSetting(
      emoji: '💾',
      name: 'Cache Interceptor',
      className: 'CacheInterceptor',
      description: 'Serves GET responses from local Hive cache with a 5-minute TTL. Respects Cache-Control headers from the server.',
      color: AppColors.tagCache,
    ),
    _InterceptorSetting(
      emoji: '🔑',
      name: 'Auth Interceptor',
      className: 'AuthInterceptor',
      description: 'Attaches Bearer token to every request. Auto-refreshes on 401 and retries the original request silently.',
      color: AppColors.tagAuth,
    ),
    _InterceptorSetting(
      emoji: '❌',
      name: 'Error Interceptor',
      className: 'ErrorInterceptor',
      description: 'Transforms raw DioExceptions into typed AppException subclasses: NetworkException, UnauthorizedException, ValidationException...',
      color: AppColors.error,
    ),
    _InterceptorSetting(
      emoji: '🔐',
      name: 'Encrypt Interceptor',
      className: 'EncryptInterceptor',
      description: 'Encrypts request body with AES-256-CBC for endpoints marked with extra["encrypt"] = true. Key stored in TokenStorage.',
      color: AppColors.tagSecurity,
    ),
    _InterceptorSetting(
      emoji: '⚡',
      name: 'Performance Interceptor',
      className: 'PerformanceInterceptor',
      description: 'Measures request duration. Logs a warning for requests exceeding the threshold. Emits PerformanceMetric to analytics.',
      color: AppColors.tagPerf,
    ),
    _InterceptorSetting(
      emoji: '🧭',
      name: 'Navigation Interceptor',
      className: 'NavigationInterceptor',
      description: 'Attaches the current screen route as X-Screen-Origin header. Used for analytics to track which screen triggered each request.',
      color: AppColors.tagState,
    ),
    _InterceptorSetting(
      emoji: '🗑️',
      name: 'Soft Delete Interceptor',
      className: 'SoftDeleteInterceptor',
      description: 'Transforms DELETE requests into PATCH with { deleted_at: now }. Filters soft-deleted records from GET list responses.',
      color: AppColors.warning,
    ),
    _InterceptorSetting(
      emoji: '✅',
      name: 'Validator Interceptor',
      className: 'ValidatorInterceptor',
      description: 'Validates request body against a schema before sending. Rejects immediately without a network call if invalid.',
      color: AppColors.success,
    ),
    _InterceptorSetting(
      emoji: '🔄',
      name: 'State Interceptor',
      className: 'StateInterceptor',
      description: 'Bridges network layer to BLoC. Emits NetworkLoading, NetworkSuccess, NetworkError states to a global NetworkCubit.',
      color: AppColors.tagState,
    ),
    _InterceptorSetting(
      emoji: '👆',
      name: 'Bio Auth Interceptor',
      className: 'BioAuthDioInterceptor',
      description: 'Requires biometric authentication before sensitive endpoints like /auth/profile/delete. Skipped automatically on web.',
      color: AppColors.tagSecurity,
    ),
    _InterceptorSetting(
      emoji: '🔒',
      name: 'Root Detection',
      className: 'RootDetectionDioInterceptor',
      description: 'Adds X-Device-Rooted header to every request. Warns users on rooted/jailbroken devices. Skipped automatically on web.',
      color: AppColors.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const _AppBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Sidebar(currentRoute: 'settings'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // ── App config ─────────────────────────────────────
                      const _SectionTitle(title: 'APP CONFIGURATION'),
                      const SizedBox(height: 10),
                      const _AppConfigCard(),
                      const SizedBox(height: 28),

                      // ── Interceptors ───────────────────────────────────
                      Row(
                        children: [
                          const _SectionTitle(title: 'INTERCEPTOR CHAIN'),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentDim,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${_interceptors.length} active',
                              style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Chain order note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentGlow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                        ),
                        child: const Row(
                          children: [
                            Text('ℹ️', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Interceptors run top→bottom on request, bottom→top on response/error. '
                                'All interceptors are enabled and wired to real API calls.',
                                style: TextStyle(color: AppColors.accent, fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Interceptor cards
                      ..._interceptors.asMap().entries.map((entry) {
                        final index = entry.key;
                        final setting = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _InterceptorCard(setting: setting, order: index + 1),
                        );
                      }),

                      const SizedBox(height: 28),

                      // ── Danger zone ────────────────────────────────────
                      const _SectionTitle(title: 'DANGER ZONE', color: AppColors.error),
                      const SizedBox(height: 10),
                      const _DangerZone(),
                      const SizedBox(height: 40),
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

// ─── AppBar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  const _AppBar();

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
          const Text('settings', style: TextStyle(color: AppColors.accent, fontSize: 13)),
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
              child: GestureDetector(
                onTap: () {
                  if (item.id == 'posts') context.go('/posts');
                  if (item.id == 'dashboard') context.go('/dashboard');
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

// ─── Section Title ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionTitle({required this.title, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

// ─── App Config Card ──────────────────────────────────────────────────────────
class _AppConfigCard extends StatelessWidget {
  const _AppConfigCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          _ConfigRow(
            icon: '🌐',
            label: 'Base URL',
            value: 'http://localhost:3000/api',
          ),
          Divider(color: AppColors.border, height: 1),
          _ConfigRow(
            icon: '🌙',
            label: 'Dark Theme',
            value: 'Enabled',
          ),
          Divider(color: AppColors.border, height: 1),
          _ConfigRow(
            icon: '📋',
            label: 'Verbose Logs',
            value: 'Enabled — printed to terminal',
          ),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String icon, label, value;
  const _ConfigRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          Text(value, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Interceptor Card ─────────────────────────────────────────────────────────
class _InterceptorCard extends StatelessWidget {
  final _InterceptorSetting setting;
  final int order;

  const _InterceptorCard({required this.setting, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: setting.color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Order badge
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: setting.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: setting.color.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text(
                      '$order',
                      style: TextStyle(color: setting.color, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(setting.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setting.name,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        setting.className,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'Courier New'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 34), // align with name
                Expanded(
                  child: Text(
                    setting.description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
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

// ─── Danger Zone ─────────────────────────────────────────────────────────────
class _DangerZone extends StatelessWidget {
  const _DangerZone();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _DangerRow(
            icon: '💾',
            title: 'Clear Cache',
            subtitle: 'Invalidates all cached GET responses in Hive',
            buttonLabel: 'Clear',
            buttonColor: AppColors.warning,
            onTap: () => _showConfirm(context, 'Clear Cache', 'This will delete all cached responses. The next request for each endpoint will hit the network.', () async {
              await CacheInterceptor.clearAll();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(_snackbar('Cache cleared ✓', AppColors.warning));
            }),
          ),
          const Divider(color: AppColors.border, height: 1),
          _DangerRow(
            icon: '🔑',
            title: 'Clear Auth Tokens',
            subtitle: 'Deletes access and refresh tokens from secure storage',
            buttonLabel: 'Logout',
            buttonColor: AppColors.error,
            onTap: () => _showConfirm(context, 'Clear Auth Tokens', 'You will be logged out immediately.', () async {
              await TokenStorage.create().deleteAll();
              if (context.mounted) context.go('/login');
            }),
          ),
        ],
      ),
    );
  }

  void _showConfirm(BuildContext context, String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () { Navigator.pop(context); onConfirm(); },
            child: const Text('Confirm', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  SnackBar _snackbar(String text, Color color) {
    return SnackBar(
      content: Text(text, style: TextStyle(color: color)),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
    );
  }
}

class _DangerRow extends StatelessWidget {
  final String icon, title, subtitle, buttonLabel;
  final Color buttonColor;
  final VoidCallback onTap;

  const _DangerRow({
    required this.icon, required this.title, required this.subtitle,
    required this.buttonLabel, required this.buttonColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: buttonColor,
              side: BorderSide(color: buttonColor.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(buttonLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────
class _InterceptorSetting {
  final String emoji, name, className, description;
  final Color color;

  _InterceptorSetting({
    required this.emoji,
    required this.name,
    required this.className,
    required this.description,
    required this.color,
  });
}
