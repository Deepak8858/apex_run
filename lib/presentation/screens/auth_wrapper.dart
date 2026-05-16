import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/main_navigation.dart';
import 'login_screen.dart';
import 'onboarding_profile_screen.dart';
import 'permission_screen.dart';
import 'value_prop_screen.dart';

/// Onboarding flags persisted in shared_preferences.
const _kValuePropSeenKey = 'value_prop_seen';
const _kPermissionsCompletedKey = 'permissions_completed';

final _valuePropSeenProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kValuePropSeenKey) ?? false;
});

final _permissionsCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kPermissionsCompletedKey) ?? false;
});

/// First-launch flow:
///   1. ValuePropScreen        (one-time, before auth)
///   2. PermissionScreen       (one-time, before auth — soft asks)
///   3. LoginScreen            (auth)
///   4. OnboardingProfileScreen (per-account, once)
///   5. MainNavigation         (main app)
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valuePropSeen = ref.watch(_valuePropSeenProvider);
    final permsDone = ref.watch(_permissionsCompletedProvider);

    return valuePropSeen.when(
      loading: _loading,
      error: (_, _) => _loading(),
      data: (seen) {
        if (!seen) {
          return ValuePropScreen(
            onContinue: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_kValuePropSeenKey, true);
              ref.invalidate(_valuePropSeenProvider);
            },
          );
        }

        return permsDone.when(
          loading: _loading,
          error: (_, _) => _loading(),
          data: (done) {
            if (!done) {
              return PermissionScreen(
                onComplete: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_kPermissionsCompletedKey, true);
                  ref.invalidate(_permissionsCompletedProvider);
                },
              );
            }

            // Permissions handled. Now check auth.
            final authState = ref.watch(authStateProvider);
            if (authState == AuthStatus.initial ||
                authState == AuthStatus.loading) {
              return _loading();
            }
            if (authState != AuthStatus.authenticated) {
              return const LoginScreen();
            }

            // Authenticated — check per-account profile completion.
            final profileCompleted = ref.watch(profileCompletedProvider);
            return profileCompleted.when(
              loading: _loading,
              error: (_, _) => const MainNavigation(),
              data: (completed) {
                if (!completed) {
                  return OnboardingProfileScreen(
                    onComplete: () => ref.invalidate(profileCompletedProvider),
                  );
                }
                return const MainNavigation();
              },
            );
          },
        );
      },
    );
  }

  static Widget _loading() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
