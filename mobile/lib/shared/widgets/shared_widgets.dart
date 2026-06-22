import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Interceptor Tag Badge ────────────────────────────────────────────────────
class InterceptorBadge extends StatelessWidget {
  final String label;
  final Color color;
  final String? emoji;

  const InterceptorBadge({
    super.key,
    required this.label,
    required this.color,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Dot ──────────────────────────────────────────────────────────────
class StatusDot extends StatelessWidget {
  final Color color;
  final bool pulse;

  const StatusDot({super.key, required this.color, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 2)]
            : null,
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── Terminal Log Tile ────────────────────────────────────────────────────────
class LogTile extends StatelessWidget {
  final String method;
  final String path;
  final int? statusCode;
  final int durationMs;
  final DateTime time;
  final List<InterceptorBadge> badges;

  const LogTile({
    super.key,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    required this.time,
    this.badges = const [],
  });

  Color get _statusColor {
    if (statusCode == null) return AppColors.error;
    if (statusCode! < 300) return AppColors.success;
    if (statusCode! < 400) return AppColors.warning;
    return AppColors.error;
  }

  Color get _methodColor {
    switch (method) {
      case 'GET': return AppColors.success;
      case 'POST': return AppColors.accent;
      case 'PATCH': return AppColors.warning;
      case 'DELETE': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  method,
                  style: TextStyle(
                    color: _methodColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (statusCode != null)
                Text(
                  '$statusCode',
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 56),
              Text(
                '${durationMs}ms',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              ...badges.map((b) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: b,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Glass Card ───────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// ─── Network State Banner ─────────────────────────────────────────────────────
class NetworkBanner extends StatelessWidget {
  final bool isOnline;

  const NetworkBanner({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.errorDim,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StatusDot(color: AppColors.error, pulse: true),
          SizedBox(width: 8),
          Text(
            'No internet connection',
            style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
