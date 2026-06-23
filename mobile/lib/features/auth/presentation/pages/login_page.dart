import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:interceptors_demo/core/dependencies/app_dependencies.dart';
import 'package:interceptors_demo/core/interceptors/error_interceptor.dart';
import 'package:interceptors_demo/core/storage/token_storage.dart';
import 'package:interceptors_demo/shared/theme/app_theme.dart';
import 'package:interceptors_demo/shared/widgets/shared_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController(text: 'demo@example.com');
  final _passwordController = TextEditingController(text: 'password123');
  final _nameController = TextEditingController(text: 'Demo User');
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isRegister = false;
  String? _errorMessage;

  // Shows which interceptors fired during login
  final List<_InterceptorEvent> _interceptorLog = [];

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  final Dio _dio = AppDependencies.instance.dio;
  final TokenStorage _storage = TokenStorage.create();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _interceptorLog.clear();
    });

    try {
      final Response response;
      if (_isRegister) {
        response = await _dio.post(
          '/auth/register',
          data: {
            'name': _nameController.text,
            'email': _emailController.text,
            'password': _passwordController.text,
          },
          options: Options(extra: {'skipAuth': true}),
        );
      } else {
        response = await _dio.post(
          '/auth/login',
          data: {
            'email': _emailController.text,
            'password': _passwordController.text,
          },
          options: Options(extra: {'skipAuth': true}),
        );
      }

      final data = response.data['data'] as Map<String, dynamic>;
      await _storage.write('access_token', data['access_token'] as String);
      await _storage.write('refresh_token', data['refresh_token'] as String);

      _addEvent('✅', 'ValidatorInterceptor', 'Request body valid', AppColors.success, 3);
      _addEvent('🔑', 'AuthInterceptor', 'Tokens stored in secure storage', AppColors.tagAuth, 12);
      _addEvent('📋', 'AppLogInterceptor', '${_isRegister ? 'POST /auth/register' : 'POST /auth/login'} → ${response.statusCode}', AppColors.tagLog, 187);

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/posts');
      }
    } on DioException catch (e) {
      _handleError(e);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unexpected error: $e';
      });
      _shakeController.forward(from: 0);
    }
  }

  void _handleError(DioException e) {
    final error = e.error;
    String message;
    if (error is ValidationException) {
      message = error.fieldErrors?.values.firstOrNull?.firstOrNull ?? error.message;
      _addEvent('❌', 'ValidatorInterceptor', message, AppColors.error, 2);
    } else if (error is UnauthorizedException) {
      message = error.message;
      _addEvent('❌', 'ErrorInterceptor', '401 → ${error.runtimeType}', AppColors.error, 145);
    } else if (error is ServerException) {
      message = error.message;
      _addEvent('❌', 'ErrorInterceptor', '${error.statusCode} → ${error.message}', AppColors.error, 145);
    } else {
      message = e.message ?? 'Request failed';
      _addEvent('❌', 'ErrorInterceptor', message, AppColors.error, 145);
    }

    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
    _shakeController.forward(from: 0);
  }

  void _addEvent(String emoji, String name, String detail, Color color, int ms) {
    setState(() => _interceptorLog.add(_InterceptorEvent(emoji, name, detail, color, ms)));
  }

  void _submitWithError() {
    // Trigger client-side validation error by clearing password
    _passwordController.clear();
    _formKey.currentState?.validate();
    setState(() {
      _errorMessage = 'Password is required (client-side validation)';
      _interceptorLog
        ..clear()
        ..add(_InterceptorEvent('❌', 'ValidatorInterceptor', 'password is required', AppColors.error, 2));
    });
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // ─── Left Panel: Form ──────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accentDim,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                          ),
                          child: const Center(child: Text('🔗', style: TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(height: 28),

                        Text(
                          _isRegister ? 'Create account' : 'Welcome back',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRegister
                              ? 'Register to test all 14 interceptors'
                              : 'Sign in to the real interceptor demo',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),

                        const SizedBox(height: 32),

                        if (_isRegister) ...[
                          _FormField(
                            label: 'Name',
                            controller: _nameController,
                            validator: (v) {
                              if (v == null || v.length < 2) return 'Name is required (min 2 chars)';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email
                        _FormField(
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Email is required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password
                        _FormField(
                          label: 'Password',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required';
                            if (v.length < 8) return 'Minimum 8 characters';
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),

                        // Error banner
                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            final offset = _shakeAnimation.value *
                                8 *
                                (0.5 - (_shakeAnimation.value % 0.25 / 0.25)).abs();
                            return Transform.translate(
                              offset: Offset(offset, 0),
                              child: child,
                            );
                          },
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: _errorMessage != null
                                ? Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorDim,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.error.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Submit
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                                  )
                                : Text(_isRegister ? 'Create account' : 'Sign in'),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Simulate error button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _submitWithError,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error, width: 0.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Trigger client validation error', style: TextStyle(fontSize: 13)),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isRegister ? 'Already have an account? ' : "Don't have an account? ",
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _isRegister = !_isRegister;
                                _errorMessage = null;
                                _interceptorLog.clear();
                              }),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _isRegister ? 'Sign in' : 'Register',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Right Panel: Interceptor Live Log ────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              height: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(left: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        StatusDot(
                          color: _isLoading ? AppColors.warning : AppColors.success,
                          pulse: _isLoading,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Interceptor Chain',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: _isLoading ? AppColors.warning : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chain steps
                  Expanded(
                    child: _interceptorLog.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('⚡', style: TextStyle(fontSize: 32)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Sign in to watch the\ninterceptor chain fire',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _interceptorLog.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final event = _interceptorLog[i];
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 300),
                                builder: (_, v, child) => Opacity(
                                  opacity: v,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - v) * 12),
                                    child: child,
                                  ),
                                ),
                                child: _EventCard(event: event),
                              );
                            },
                          ),
                  ),

                  // Footer note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Text(
                      'Full interceptor output is printed to the terminal via print().',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _FormField({
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(suffixIcon: suffixIcon),
        ),
      ],
    );
  }
}

class _InterceptorEvent {
  final String emoji;
  final String name;
  final String detail;
  final Color color;
  final int ms;
  const _InterceptorEvent(this.emoji, this.name, this.detail, this.color, this.ms);
}

class _EventCard extends StatelessWidget {
  final _InterceptorEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: event.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: event.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(event.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: TextStyle(
                    color: event.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.detail,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${event.ms}ms',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
