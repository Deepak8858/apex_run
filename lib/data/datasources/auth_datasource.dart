import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// Sign in with Google (native flow via google_sign_in + Supabase ID Token)
  ///
  /// Uses native Google Sign-In for a seamless experience, then exchanges
  /// the ID token with Supabase for a session. Falls back to OAuth browser
  /// flow if native sign-in is unavailable.
  Future<AuthResponse> signInWithGoogle() async {
    try {
      print('🔐 Starting native Google Sign-In...');
      
      // Use the web client ID from Google Cloud Console for Supabase
      // This must match the client ID configured in Supabase Auth > Google provider
      const webClientId = '816058498934-9v7gdfr5r4fhhq6dn3e5a8nk72l1rqtq.apps.googleusercontent.com';
      
      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Google sign-in was cancelled');
      }
      
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      
      if (idToken == null) {
        throw const AuthException('Failed to get Google ID token');
      }
      
      print('✅ Google native sign-in successful, exchanging with Supabase...');
      
      // Exchange the Google ID token with Supabase
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      print('✅ Supabase session created for: ${response.user?.email}');
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      print('⚠️ Native Google Sign-In failed: $e');
      print('📱 Falling back to OAuth browser flow...');
      
      // Fallback to Supabase OAuth browser flow
      try {
        final success = await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'apexrun://login-callback',
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        
        if (!success) {
          throw const AuthException('Failed to launch Google sign-in');
        }
        
        print('✅ Google OAuth browser launched');
        return AuthResponse(session: null, user: null);
      } catch (fallbackError) {
        print('❌ Fallback OAuth also failed: $fallbackError');
        throw AuthException('Google sign-in failed: $e');
      }
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
