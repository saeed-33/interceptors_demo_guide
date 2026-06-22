import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:interceptors_demo/shared/theme/app_theme.dart';
import 'package:interceptors_demo/shared/widgets/shared_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ─── Interceptor toggles ──────────────────────────────────────────────────
  final List<_InterceptorSetting> _interceptors = [
    _InterceptorSetting(
      emoji: '🌐',
      name: 'Network Interceptor',
      className: 'NetworkInterceptor',
      description: 'Checks internet connectivity before every request. Aborts with a typed NetworkException when offline.',
      color: AppColors.tagNetwork,
      enabled: true,
      canDisable: false, // always required
    ),
    _InterceptorSetting(
      emoji: '📋',
      name: 'Log Interceptor',
      className: 'AppLogInterceptor',
      description: 'Logs every request, response and error in a structured, color-coded format. Sanitizes Authorization headers.',
      color: AppColors.tagLog,
      enabled: true,
    ),
    _InterceptorSetting(
      emoji: '💾',
      name: 'Cache Interceptor',
      className: 'CacheInterceptor',
      description: 'Serves GET responses from local Hive cache with a 5-minute TTL. Respects Cache-Control headers from the server.',
      color: AppColors.tagCache,
      enabled: true,
      ttlMinutes: 5,
    ),
    _InterceptorSetting(
      emoji: '🔑',
      name: 'Auth Interceptor',
      className: 'AuthInterceptor',
      description: 'Attaches Bearer token to every request. Auto-refreshes on 401 and retries the original request silently.',
      color: AppColors.tagAuth,
      enabled: true,
      canDisable: false,
    ),
    _InterceptorSetting(
      emoji: '❌',
      name: 'Error Interceptor',
      className: 'ErrorInterceptor',
      description: 'Transforms raw DioExceptions into typed AppException subclasses: NetworkException, UnauthorizedException, ValidationException...',
      color: AppColors.error,
      enabled: true,
      canDisable: false,
    ),
    _InterceptorSetting(
      emoji: '🔐',
      name: 'Encrypt Interceptor',
      className: 'EncryptInterceptor',
      description: 'Encrypts request body with AES-256-CBC for endpoints marked with extra[\'encrypt\'] = true. Key stored in FlutterSecureStorage.',
      color: AppColors.tagSecurity,
      enabled: false,
    ),
    _InterceptorSetting(
      emoji: '⚡',
      name: 'Performance Interceptor',
      className: 'PerformanceInterceptor',
      description: 'Measures request duration. Logs a warning for requests exceeding the threshold. Emits PerformanceMetric to analytics.',
      color: AppColors.tagPerf,
      enabled: true,
      warnThresholdMs: 2000,
    ),
    _InterceptorSetting(
      emoji: '🧭',
      name: 'Navigation Interceptor',
      className: 'NavigationInterceptor',
      description: 'Attaches the current screen route as X-Screen-Origin header. Used for analytics to track which screen triggered each request.',
      color: AppColors.tagState,
      enabled: true,
    ),
    _InterceptorSetting(
      emoji: '🗑️',
      name: 'Soft Delete Interceptor',
      className: 'SoftDeleteInterceptor',
      description: 'Transforms DELETE requests into PATCH with { deleted_at: now }. Filters soft-deleted records from GET list responses.',
      color: AppColors.warning,
      enabled: true,
    ),
    _InterceptorSetting(
      emoji: '✅',
      name: 'Validator Interceptor',
      className: 'ValidatorInterceptor',
      description: 'Validates request body against a schema before sending. Rejects immediately without a network call if invalid.',
      color: AppColors.success,
      enabled: true,
    ),
    _InterceptorSetting(
      emoji: '🔄',
      name: 'State Interceptor',
      className: 'StateInterceptor',
      description: 'Bridges network layer to BLoC. Emits NetworkLoading, NetworkSuccess, NetworkError states to a global NetworkCubit.',
      color: AppColors.tagState,
      enabled: true,
    ),
    _InterceptorSetting(
      emoji: '👆',
      name: 'Bio Auth Interceptor',
      className: 'BioAuthDioInterceptor',
      description: 'Requires biometric authentication before sensitive endpoints like /payments or /profile/delete.',
      color: AppColors.tagSecurity,
      enabled: false,
    ),
    _InterceptorSetting(
      emoji: '📵',
      name: 'Screenshot Prevention',
      className: 'ScreenshotInterceptor',
      description: 'Sets FLAG_SECURE on Android to block screenshots. Blurs app content in the iOS/Android app switcher.',
      color: AppColors.error,
      enabled: true,
    ),
    _InterceptorSetting(
      emoji: '🔒',
      name: 'Root Detection',
      className: 'RootDetectionDioInterceptor',
      description: 'Adds X-Device-Rooted header to every request. Warns users on rooted/jailbroken devices. Can block requests entirely.',
      color: AppColors.warning,
      enabled: true,
      blockRooted: false,
    ),
  ];

  // ─── App settings ─────────────────────────────────────────────────────────
  String _baseUrl = 'http://localhost:3000/api';
  bool _darkTheme = true;
  bool _verboseLogs = true;

  int get _activeCount => _interceptors.where((i) => i.enabled).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _AppBar(activeCount: _activeCount, total: _interceptors.length),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Sidebar(currentRoute: 'settings'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // ── App config ─────────────────────────────────────
                      _SectionTitle(title: 'APP CONFIGURATION'),
                      const SizedBox(height: 10),
                      _AppConfigCard(
                        baseUrl: _baseUrl,
                        darkTheme: _darkTheme,
                        verboseLogs: _verboseLogs,
                        onBaseUrlChanged: (v) => setState(() => _baseUrl = v),
                        onDarkThemeChanged: (v) => setState(() => _darkTheme = v),
                        onVerboseLogsChanged: (v) => setState(() => _verboseLogs = v),
                      ),
                      const SizedBox(height: 28),

                      // ── Interceptors ───────────────────────────────────
                      Row(
                        children: [
                          const _SectionTitle(title: 'INTERCEPTORS'),
                          const Spacer(),
                          _QuickAction(
                            label: 'Enable all',
                            color: AppColors.success,
                            onTap: () => setState(() {
                              for (final i in _interceptors) {
                                if (i.canDisable) i.enabled = true;
                              }
                            }),
                          ),
                          const SizedBox(width: 8),
                          _QuickAction(
                            label: 'Disable optional',
                            color: AppColors.error,
                            onTap: () => setState(() {
                              for (final i in _interceptors) {
                                if (i.canDisable) i.enabled = false;
                              }
                            }),
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
                        child: Row(
                          children: [
                            const Text('ℹ️', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Interceptors run top→bottom on request, bottom→top on response/error. '
                                'Disabled interceptors are removed from the chain entirely.',
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
                          child: _InterceptorCard(
                            setting: setting,
                            order: index + 1,
                            onToggle: setting.canDisable
                                ? (v) => setState(() => setting.enabled = v)
                                : null,
                            onTtlChanged: (v) => setState(() => setting.ttlMinutes = v),
                            onWarnThresholdChanged: (v) => setState(() => setting.warnThresholdMs = v),
                            onBlockRootedChanged: (v) => setState(() => setting.blockRooted = v),
                          ),
                        );
                      }),

                      const SizedBox(height: 28),

                      // ── Danger zone ────────────────────────────────────
                      _SectionTitle(title: 'DANGER ZONE', color: AppColors.error),
                      const SizedBox(height: 10),
                      _DangerZone(),
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
  final int activeCount, total;
  const _AppBar({required this.activeCount, required this.total});

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
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Text(
              '$activeCount / $total active',
              style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
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
  final String baseUrl;
  final bool darkTheme, verboseLogs;
  final ValueChanged<String> onBaseUrlChanged;
  final ValueChanged<bool> onDarkThemeChanged;
  final ValueChanged<bool> onVerboseLogsChanged;

  const _AppConfigCard({
    required this.baseUrl,
    required this.darkTheme,
    required this.verboseLogs,
    required this.onBaseUrlChanged,
    required this.onDarkThemeChanged,
    required this.onVerboseLogsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _ConfigRow(
            icon: '🌐',
            label: 'Base URL',
            child: SizedBox(
              width: 260,
              height: 32,
              child: TextField(
                controller: TextEditingController(text: baseUrl),
                onChanged: onBaseUrlChanged,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'Courier New'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.accent)),
                ),
              ),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          _ConfigRow(
            icon: '🌙',
            label: 'Dark Theme',
            child: _Toggle(value: darkTheme, onChanged: onDarkThemeChanged, color: AppColors.accent),
          ),
          const Divider(color: AppColors.border, height: 1),
          _ConfigRow(
            icon: '📋',
            label: 'Verbose Logs (dev mode)',
            child: _Toggle(value: verboseLogs, onChanged: onVerboseLogsChanged, color: AppColors.tagLog),
          ),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String icon, label;
  final Widget child;
  const _ConfigRow({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          child,
        ],
      ),
    );
  }
}

// ─── Interceptor Card ─────────────────────────────────────────────────────────
class _InterceptorCard extends StatelessWidget {
  final _InterceptorSetting setting;
  final int order;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<int> onTtlChanged;
  final ValueChanged<int> onWarnThresholdChanged;
  final ValueChanged<bool> onBlockRootedChanged;

  const _InterceptorCard({
    required this.setting,
    required this.order,
    required this.onToggle,
    required this.onTtlChanged,
    required this.onWarnThresholdChanged,
    required this.onBlockRootedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = setting.enabled;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isEnabled ? AppColors.surface : AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEnabled ? setting.color.withOpacity(0.25) : AppColors.border.withOpacity(0.4),
        ),
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
                    color: isEnabled ? setting.color.withOpacity(0.15) : AppColors.textMuted.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isEnabled ? setting.color.withOpacity(0.4) : AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      '$order',
                      style: TextStyle(
                        color: isEnabled ? setting.color : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(setting.emoji, style: TextStyle(fontSize: 16, color: isEnabled ? null : const Color(0x44FFFFFF))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setting.name,
                        style: TextStyle(
                          color: isEnabled ? AppColors.textPrimary : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        setting.className,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontFamily: 'Courier New',
                        ),
                      ),
                    ],
                  ),
                ),
                // Required badge
                if (!setting.canDisable)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text('required', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  ),
                _Toggle(
                  value: isEnabled,
                  onChanged: onToggle,
                  color: setting.color,
                ),
              ],
            ),
          ),

          // Description
          if (isEnabled) ...[
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

            // Extra controls for specific interceptors
            if (setting.ttlMinutes != null)
              _SubSetting(
                label: 'Cache TTL',
                child: _SliderControl(
                  value: setting.ttlMinutes!.toDouble(),
                  min: 1, max: 60,
                  label: '${setting.ttlMinutes} min',
                  color: setting.color,
                  onChanged: (v) => onTtlChanged(v.round()),
                ),
              ),

            if (setting.warnThresholdMs != null)
              _SubSetting(
                label: 'Warn threshold',
                child: _SliderControl(
                  value: setting.warnThresholdMs!.toDouble(),
                  min: 500, max: 5000,
                  label: '${(setting.warnThresholdMs! / 1000).toStringAsFixed(1)}s',
                  color: setting.color,
                  onChanged: (v) => onWarnThresholdChanged(v.round()),
                ),
              ),

            if (setting.blockRooted != null)
              _SubSetting(
                label: 'Block rooted devices',
                child: _Toggle(
                  value: setting.blockRooted!,
                  onChanged: onBlockRootedChanged,
                  color: AppColors.error,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SubSetting extends StatelessWidget {
  final String label;
  final Widget child;
  const _SubSetting({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 8, 14, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

class _SliderControl extends StatelessWidget {
  final double value, min, max;
  final String label;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SliderControl({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: AppColors.border,
              thumbColor: color,
              overlayColor: color.withOpacity(0.1),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Danger Zone ─────────────────────────────────────────────────────────────
class _DangerZone extends StatelessWidget {
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
            onTap: () => _showConfirm(context, 'Clear Cache', 'This will delete all cached responses. The next request for each endpoint will hit the network.', () {
              ScaffoldMessenger.of(context).showSnackBar(_snackbar('Cache cleared ✓', AppColors.warning));
            }),
          ),
          const Divider(color: AppColors.border, height: 1),
          _DangerRow(
            icon: '🔑',
            title: 'Clear Auth Tokens',
            subtitle: 'Deletes access and refresh tokens from secure storage',
            buttonLabel: 'Clear',
            buttonColor: AppColors.error,
            onTap: () => _showConfirm(context, 'Clear Auth Tokens', 'You will be logged out immediately.', () {
              context.go('/login');
            }),
          ),
          const Divider(color: AppColors.border, height: 1),
          _DangerRow(
            icon: '🔄',
            title: 'Reset All Settings',
            subtitle: 'Restore all interceptor toggles to their defaults',
            buttonLabel: 'Reset',
            buttonColor: AppColors.error,
            onTap: () => _showConfirm(context, 'Reset Settings', 'All interceptor settings will return to defaults.', () {
              ScaffoldMessenger.of(context).showSnackBar(_snackbar('Settings reset ✓', AppColors.success));
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

// ─── Quick Action ─────────────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── Toggle ───────────────────────────────────────────────────────────────────
class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color color;

  const _Toggle({required this.value, required this.onChanged, required this.color});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: color,
      activeTrackColor: color.withOpacity(0.3),
      inactiveThumbColor: AppColors.textMuted,
      inactiveTrackColor: AppColors.border,
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────
class _InterceptorSetting {
  final String emoji, name, className, description;
  final Color color;
  bool enabled;
  final bool canDisable;
  int? ttlMinutes;
  int? warnThresholdMs;
  bool? blockRooted;

  _InterceptorSetting({
    required this.emoji,
    required this.name,
    required this.className,
    required this.description,
    required this.color,
    required this.enabled,
    this.canDisable = true,
    this.ttlMinutes,
    this.warnThresholdMs,
    this.blockRooted,
  });
}
