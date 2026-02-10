import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication Repository Interface
///
/// Defines authentication operations for the domain layer.
/// Implemented by AuthRepositoryImpl in the data layer.
abstract class AuthRepository {
  /// Get current authenticated user
  User? get currentUser;

  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges;

  /// Check if user is authenticated
  bool get isAuthenticated;

  /// Sign in with email and password
  Future<User> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign up with email and password
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sign in with Google
  Future<User> signInWithGoogle();

  /// Sign in with Apple
  Future<User> signInWithApple();

  /// Sign out
  Future<void> signOut();

  /// Reset password
  Future<void> resetPassword({required String email});

  /// Update password
  Future<void> updatePassword({required String newPassword});
}
