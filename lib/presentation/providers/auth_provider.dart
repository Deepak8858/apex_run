import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/logger/app_logger.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/services/revenue_cat_service.dart';
import '../../domain/repositories/auth_repository.dart';

final _log = AppLogger.tag('AuthState');

/// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for AuthDataSource
final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthDataSource(supabase);
});

/// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(authDataSourceProvider);
  return AuthRepositoryImpl(dataSource);
});

/// Current user provider
final currentUserProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges.map((state) => state.session?.user);
});

/// Auth state provider (authenticated/unauthenticated)
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthStatus>(
  (ref) {
    final repository = ref.watch(authRepositoryProvider);
    return AuthStateNotifier(repository);
  },
);

/// Auth status enum
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

/// Auth State Notifier
class AuthStateNotifier extends StateNotifier<AuthStatus> {
  final AuthRepository _repository;

  AuthStateNotifier(this._repository) : super(AuthStatus.initial) {
    _init();
  }

  void _init() {
    // Check initial auth state
    if (_repository.isAuthenticated) {
      state = AuthStatus.authenticated;
    } else {
      state = AuthStatus.unauthenticated;
    }

    // Listen to auth state changes
    _repository.authStateChanges.listen((authState) {
      final session = authState.session;
      if (session != null) {
        state = AuthStatus.authenticated;
        // Bind RevenueCat to Supabase user id so the webhook can find the
        // right `subscriptions` row.
        RevenueCatService.identify(session.user.id);
      } else {
        state = AuthStatus.unauthenticated;
        RevenueCatService.resetOnSignOut();
      }
    });
  }

  User? get currentUser => _repository.currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _log.i('Email sign-in started');
      state = AuthStatus.loading;
      await _repository.signInWithEmail(email: email, password: password);
      state = AuthStatus.authenticated;
      _log.i('Email sign-in authenticated');
    } catch (e, st) {
      _log.e('Email sign-in error', error: e, stackTrace: st);
      state = AuthStatus.unauthenticated;
      rethrow;
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _log.i('Email sign-up started');
      state = AuthStatus.loading;
      await _repository.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AuthStatus.authenticated;
      _log.i('Email sign-up authenticated');
    } catch (e, st) {
      _log.e('Email sign-up error', error: e, stackTrace: st);
      state = AuthStatus.unauthenticated;
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      state = AuthStatus.loading;
      await _repository.signInWithGoogle();
      state = AuthStatus.authenticated;
    } catch (e) {
      state = AuthStatus.unauthenticated;
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    try {
      state = AuthStatus.loading;
      await _repository.signInWithApple();
      state = AuthStatus.authenticated;
    } catch (e) {
      state = AuthStatus.unauthenticated;
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      state = AuthStatus.loading;
      await _repository.signOut();
      state = AuthStatus.unauthenticated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword({required String email}) async {
    await _repository.resetPassword(email: email);
  }

  Future<void> deleteAccount() async {
    try {
      _log.w('Account deletion requested by user');
      state = AuthStatus.loading;
      await _repository.deleteAccount();
      state = AuthStatus.unauthenticated;
      _log.w('Account deletion completed');
    } catch (e, st) {
      _log.e('Account deletion error', error: e, stackTrace: st);
      rethrow;
    }
  }
}
