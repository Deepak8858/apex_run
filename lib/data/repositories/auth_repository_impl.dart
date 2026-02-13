import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

/// Implementation of AuthRepository
class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  User? get currentUser => _dataSource.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _dataSource.authStateChanges;

  @override
  bool get isAuthenticated => _dataSource.isAuthenticated;

  @override
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dataSource.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in failed: No user returned');
      }

      return response.user!;
    } on AuthException catch (e) {
      throw Exception('Authentication error: ${e.message}');
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  @override
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final Map<String, dynamic>? metadata = displayName != null
          ? {'display_name': displayName}
          : null;

      final response = await _dataSource.signUpWithEmail(
        email: email,
        password: password,
        metadata: metadata,
      );

      if (response.user == null) {
        throw Exception('Sign up failed: No user returned');
      }

      return response.user!;
    } on AuthException catch (e) {
      throw Exception('Authentication error: ${e.message}');
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  @override
  Future<User> signInWithGoogle() async {
    try {
      final response = await _dataSource.signInWithGoogle();

      // If native flow succeeded, we have the user directly
      if (response.user != null) {
        return response.user!;
      }

      // Browser fallback: wait for auth state change from deep-link redirect
      final user = await _dataSource.authStateChanges
          .where((state) => state.session != null)
          .map((state) => state.session?.user)
          .firstWhere((user) => user != null)
          .timeout(
            const Duration(seconds: 120),
            onTimeout: () => throw Exception(
              'Google sign-in timed out. Please complete sign-in in your browser and return to the app.',
            ),
          );

      return user!;
    } on AuthException catch (e) {
      throw Exception('Google authentication error: ${e.message}');
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  @override
  Future<User> signInWithApple() async {
    try {
      final response = await _dataSource.signInWithApple();

      if (response.user == null) {
        throw Exception('Apple sign in failed: No user returned');
      }

      return response.user!;
    } on AuthException catch (e) {
      throw Exception('Apple authentication error: ${e.message}');
    } catch (e) {
      throw Exception('Apple sign in failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _dataSource.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _dataSource.resetPassword(email: email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _dataSource.updatePassword(newPassword: newPassword);
    } catch (e) {
      throw Exception('Password update failed: $e');
    }
  }
}
