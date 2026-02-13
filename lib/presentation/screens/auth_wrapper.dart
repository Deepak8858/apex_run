import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import 'login_screen.dart';
import 'onboarding_profile_screen.dart';
import 'permission_screen.dart';
import '../widgets/main_navigation.dart';

/// Whether permission onboarding has been completed
final _permissionsCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('permissions_completed') ?? false;
});

/// Auth Wrapper - Routes to login, onboarding, permission screen, or main app
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

    // Not authenticated — show login
    if (authState != AuthStatus.authenticated) {
      return const LoginScreen();
    }

    // Authenticated — check if profile onboarding is complete
    final profileCompleted = ref.watch(profileCompletedProvider);

    return profileCompleted.when(
      data: (completed) {
        if (!completed) {
          // Show onboarding screen
          return OnboardingProfileScreen(
            onComplete: () {
              ref.invalidate(profileCompletedProvider);
            },
          );
        }

        // Profile complete — check permissions
        final permsDone = ref.watch(_permissionsCompletedProvider);
        return permsDone.when(
          data: (done) {
            if (!done) {
              return PermissionScreen(
                onComplete: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('permissions_completed', true);
                  ref.invalidate(_permissionsCompletedProvider);
                },
              );
            }
            return const MainNavigation();
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const MainNavigation(),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const MainNavigation(),
    );
  }
}
