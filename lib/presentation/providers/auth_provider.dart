import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

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
      if (authState.session != null) {
        state = AuthStatus.authenticated;
      } else {
        state = AuthStatus.unauthenticated;
      }
    });
  }

  User? get currentUser => _repository.currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 AuthStateNotifier: Starting email sign-in');
      state = AuthStatus.loading;
      await _repository.signInWithEmail(email: email, password: password);
      state = AuthStatus.authenticated;
      print('🟢 AuthStateNotifier: Sign-in successful, state: authenticated');
    } catch (e) {
      print('🔴 AuthStateNotifier: Sign-in error: $e');
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
      print('🔵 AuthStateNotifier: Starting email sign-up');
      state = AuthStatus.loading;
      await _repository.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AuthStatus.authenticated;
      print('🟢 AuthStateNotifier: Sign-up successful, state: authenticated');
    } catch (e) {
      print('🔴 AuthStateNotifier: Sign-up error: $e');
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
}
