import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication Data Source using Supabase
///
/// Handles all authentication operations including sign in, sign up, sign out,
/// and session management. Supports email/password, Google, and Apple sign-in.
class AuthDataSource {
  final SupabaseClient _supabase;

  AuthDataSource(this._supabase);

  /// Get current user session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Attempting email sign-in for: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print('✅ Sign-in successful! User ID: ${response.user?.id}');
      return response;
    } catch (e) {
      print('❌ Sign-in failed: $e');
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('📝 Attempting email sign-up for: $email');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      print('✅ Sign-up successful! User ID: ${response.user?.id}, Session: ${response.session != null}');
      return response;
    } catch (e) {
      print('❌ Sign-up failed: $e');
      rethrow;
    }
  }

  /// Sign in with Google (OAuth flow via Supabase)
  ///
  /// Uses Supabase's OAuth flow which handles the entire authentication
  /// process through the browser. This works without requiring Firebase
  /// configuration or google-services.json.
  Future<AuthResponse> signInWithGoogle() async {
    try {
      print('🔐 Starting Google OAuth sign-in...');
      
      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'apexrun://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      
      if (!success) {
        throw const AuthException('Failed to launch Google sign-in');
      }
      
      print('✅ Google OAuth browser launched successfully');
      
      // For OAuth flow, we need to wait for the callback
      // The actual auth happens via the redirect
      return AuthResponse(
        session: null,
        user: null,
      );
    } catch (e) {
      print('❌ Google OAuth failed: $e');
      rethrow;
    }
  }

  /// Sign in with Apple (native flow)
  ///
  /// Uses SignInWithApple package for native sign-in, then exchanges the
  /// authorization code with Supabase for a session.
  Future<AuthResponse> signInWithApple() async {
    // Generate a random nonce for security
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Failed to get Apple ID token');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    return response;
  }

  /// Generates a cryptographically-secure random nonce
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'apexrun://reset-password',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update user password
  Future<UserResponse> updatePassword({required String newPassword}) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Update user metadata
  Future<UserResponse> updateUserMetadata({
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(data: metadata),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Refresh session
  Future<AuthResponse> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => currentSession != null && currentUser != null;
}
