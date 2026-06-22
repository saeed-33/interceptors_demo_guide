import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:interceptors_demo/shared/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _dotsController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  int _currentStep = 0;
  final List<_BootStep> _steps = [
    _BootStep('network', '🌐', 'Checking connectivity...', AppColors.tagNetwork),
    _BootStep('security', '🔒', 'Running security checks...', AppColors.tagSecurity),
    _BootStep('cache', '💾', 'Initializing cache...', AppColors.tagCache),
    _BootStep('auth', '🔑', 'Verifying session...', AppColors.tagAuth),
    _BootStep('ready', '✅', 'Ready', AppColors.success),
  ];

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();

    // Animate through boot steps
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _currentStep = i);
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Grid background
          CustomPaint(painter: _GridPainter(), size: Size.infinite),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.accentDim,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: AppColors.accent.withOpacity(0.2), blurRadius: 32, spreadRadius: 4),
                        ],
                      ),
                      child: const Center(
                        child: Text('🔗', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Title
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        const Text(
                          'Interceptors',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Demo App',
                          style: TextStyle(
                            color: AppColors.accent.withOpacity(0.8),
                            fontSize: 14,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 64),

                // Boot steps
                SizedBox(
                  width: 260,
                  child: Column(
                    children: List.generate(_steps.length, (i) {
                      final step = _steps[i];
                      final isActive = i == _currentStep;
                      final isDone = i < _currentStep;
                      final isPending = i > _currentStep;

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isPending ? 0.25 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? step.color.withOpacity(0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isActive
                                  ? step.color.withOpacity(0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(step.emoji, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  step.label,
                                  style: TextStyle(
                                    color: isActive
                                        ? step.color
                                        : isDone
                                            ? AppColors.textSecondary
                                            : AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isDone)
                                const Icon(Icons.check, color: AppColors.success, size: 14),
                              if (isActive)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: step.color,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Version tag
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'v1.0.0 · Flutter + Node.js',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootStep {
  final String key;
  final String emoji;
  final String label;
  final Color color;
  const _BootStep(this.key, this.emoji, this.label, this.color);
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C2333)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
