import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/profile_datasource.dart';
import '../../domain/models/user_profile.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

// ============================================================
// Onboarding State
// ============================================================

class OnboardingState {
  final String username;
  final bool isUsernameAvailable;
  final bool isCheckingUsername;
  final double? heightCm;
  final double? weightKg;
  final int? age;
  final String? gender;
  final String? fitnessGoal;
  final bool isSubmitting;
  final String? error;

  const OnboardingState({
    this.username = '',
    this.isUsernameAvailable = false,
    this.isCheckingUsername = false,
    this.heightCm,
    this.weightKg,
    this.age,
    this.gender,
    this.fitnessGoal,
    this.isSubmitting = false,
    this.error,
  });

  OnboardingState copyWith({
    String? username,
    bool? isUsernameAvailable,
    bool? isCheckingUsername,
    double? heightCm,
    double? weightKg,
    int? age,
    String? gender,
    String? fitnessGoal,
    bool? isSubmitting,
    String? error,
  }) {
    return OnboardingState(
      username: username ?? this.username,
      isUsernameAvailable: isUsernameAvailable ?? this.isUsernameAvailable,
      isCheckingUsername: isCheckingUsername ?? this.isCheckingUsername,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  bool get isValid =>
      username.length >= 3 &&
      isUsernameAvailable &&
      heightCm != null &&
      weightKg != null &&
      age != null &&
      gender != null &&
      fitnessGoal != null;
}

// ============================================================
// Onboarding Notifier
// ============================================================

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final ProfileDataSource _profileDataSource;
  final Ref _ref;
  Timer? _usernameDebounce;

  OnboardingNotifier(this._profileDataSource, this._ref)
      : super(const OnboardingState());

  void setUsername(String value) {
    final cleaned = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    state = state.copyWith(
      username: cleaned,
      isUsernameAvailable: false,
      isCheckingUsername: cleaned.length >= 3,
    );

    _usernameDebounce?.cancel();
    if (cleaned.length >= 3) {
      _usernameDebounce = Timer(const Duration(milliseconds: 500), () {
        _checkUsername(cleaned);
      });
    }
  }

  Future<void> _checkUsername(String username) async {
    try {
      final available = await _profileDataSource.isUsernameAvailable(username);
      if (state.username == username) {
        state = state.copyWith(
          isUsernameAvailable: available,
          isCheckingUsername: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isCheckingUsername: false);
    }
  }

  void setHeight(double value) => state = state.copyWith(heightCm: value);
  void setWeight(double value) => state = state.copyWith(weightKg: value);
  void setAge(int value) => state = state.copyWith(age: value);
  void setGender(String value) => state = state.copyWith(gender: value);
  void setFitnessGoal(String value) => state = state.copyWith(fitnessGoal: value);

  Future<bool> submitProfile() async {
    final user = _ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) {
      state = state.copyWith(error: 'Not authenticated');
      return false;
    }

    if (!state.isValid) {
      state = state.copyWith(error: 'Please fill all required fields');
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final profile = UserProfile(
        id: user.id,
        username: state.username,
        displayName: user.userMetadata?['display_name'] as String? ??
            user.userMetadata?['full_name'] as String? ??
            user.email?.split('@').first,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        heightCm: state.heightCm,
        weightKg: state.weightKg,
        age: state.age,
        gender: state.gender,
        fitnessGoal: state.fitnessGoal,
        profileCompleted: true,
      );

      await _profileDataSource.upsertProfile(profile);

      // Refresh profile controller
      _ref.read(profileControllerProvider.notifier).refresh();

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().contains('duplicate')
            ? 'Username is already taken'
            : 'Failed to save profile: $e',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    super.dispose();
  }
}

// ============================================================
// Provider
// ============================================================

final onboardingProvider =
    StateNotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
  (ref) {
    final ds = ref.watch(profileDataSourceProvider);
    return OnboardingNotifier(ds, ref);
  },
);

/// Provider to check if current user has completed onboarding
final profileCompletedProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) return false;
  final ds = ref.watch(profileDataSourceProvider);
  final profile = await ds.getProfile(user.id);
  return profile?.profileCompleted ?? false;
});
