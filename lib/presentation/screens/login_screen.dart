import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Login Screen - Email/Password and Social Auth
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    print('👆 Login button pressed - isSignUp: $_isSignUp');
    setState(() => _isLoading = true);

    try {
      final authNotifier = ref.read(authStateProvider.notifier);

      if (_isSignUp) {
        print('📝 Calling signUpWithEmail');
        await authNotifier.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        print('🔐 Calling signInWithEmail');
        await authNotifier.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (mounted) {
        print('✅ Auth successful - showing success message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSignUp ? 'Account created!' : 'Welcome back!'),
          ),
        );
      }
    } catch (e) {
      print('❌ Auth error in login screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleOAuthSignIn(String provider) async {
    setState(() => _isLoading = true);
    try {
      final authNotifier = ref.read(authStateProvider.notifier);

      if (provider == 'google') {
        await authNotifier.signInWithGoogle();
      } else if (provider == 'apple') {
        await authNotifier.signInWithApple();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        // Don't show error if user cancelled
        if (!errorMsg.contains('cancelled')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-in failed. Please try again.'),
              backgroundColor: AppTheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4, 1.0],
            colors: [
              Color(0xFF1E2F05),
              AppTheme.background,
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // Logo
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.electricLime.withValues(alpha: 0.2),
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_run_rounded,
                        size: 80,
                        color: AppTheme.electricLime,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ApexRun',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            color: Colors.white,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'PEAK PERFORMANCE',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary,
                            letterSpacing: 4.0,
                            fontWeight: FontWeight.w500,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Social Auth Buttons First (Strava-like priority)
                    _BrandedAuthButton(
                      label: 'Continue with Google',
                      iconWidget: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text('G',
                              style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ),
                      backgroundColor: const Color(0xFF1A1A1A),
                      borderColor: AppTheme.surfaceLight,
                      textColor: AppTheme.textPrimary,
                      onPressed: _isLoading ? null : () => _handleOAuthSignIn('google'),
                    ),
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 12),
                      _BrandedAuthButton(
                        label: 'Continue with Apple',
                        iconWidget: const Icon(Icons.apple_rounded,
                            size: 22, color: Colors.white),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        borderColor: AppTheme.surfaceLight,
                        textColor: AppTheme.textPrimary,
                        onPressed: _isLoading ? null : () => _handleOAuthSignIn('apple'),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: AppTheme.surfaceLight)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or sign in with email',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              )),
                        ),
                        Expanded(child: Container(height: 1, color: AppTheme.surfaceLight)),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: const TextStyle(color: AppTheme.textTertiary),
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: AppTheme.textTertiary, size: 20),
                        filled: true,
                        fillColor: AppTheme.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppTheme.surfaceLight, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppTheme.electricLime, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: AppTheme.textTertiary),
                        prefixIcon: const Icon(Icons.lock_outline_rounded,
                            color: AppTheme.textTertiary, size: 20),
                        filled: true,
                        fillColor: AppTheme.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppTheme.surfaceLight, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppTheme.electricLime, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Sign In/Sign Up Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleEmailAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.electricLime,
                          foregroundColor: AppTheme.background,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.background,
                                ),
                              )
                            : Text(
                                _isSignUp ? 'Create Account' : 'Sign In',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle Sign Up/Sign In
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 14),
                          children: [
                            TextSpan(
                                text: _isSignUp
                                    ? 'Already have an account? '
                                    : 'Don\'t have an account? '),
                            TextSpan(
                              text: _isSignUp ? 'Sign In' : 'Sign Up',
                              style: const TextStyle(
                                color: AppTheme.electricLime,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Branded auth button with custom icon widget
class _BrandedAuthButton extends StatelessWidget {
  final String label;
  final Widget iconWidget;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onPressed;

  const _BrandedAuthButton({
    required this.label,
    required this.iconWidget,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}