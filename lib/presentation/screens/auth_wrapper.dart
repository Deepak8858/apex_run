import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../widgets/main_navigation.dart';

/// Auth Wrapper - Routes to login or main app based on auth state
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // Show loading while checking auth state
    if (authState == AuthStatus.initial || authState == AuthStatus.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Route based on authentication status
    if (authState == AuthStatus.authenticated) {
      return const MainNavigation();
    } else {
      return const LoginScreen();
    }
  }
}
