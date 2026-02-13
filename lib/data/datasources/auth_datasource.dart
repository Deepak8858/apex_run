import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';

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

  /// Sign in with Google — native in-app flow with browser fallback
  ///
  /// Primary: Uses GoogleSignIn package for native in-app sign-in,
  /// then exchanges the ID token with Supabase via signInWithIdToken.
  /// Fallback: If native flow fails, falls back to browser OAuth.
  Future<AuthResponse> signInWithGoogle() async {
    try {
      print('🔐 Attempting native Google Sign-In...');

      // Try native Google Sign-In first
      try {
        final response = await _nativeGoogleSignIn();
        if (response.session != null) {
          print('✅ Native Google Sign-In successful!');
          // Ensure profile exists for the new Google user
          await _ensureProfileExists(response.user);
          return response;
        }
      } on PlatformException catch (e) {
        print('⚠️ Native Google Sign-In unavailable: ${e.message}');
        print('↪️ Falling back to browser OAuth...');
      } on AuthException catch (e) {
        // If it's a user cancellation, don't fall back to browser
        if (e.message.contains('cancelled')) {
          rethrow;
        }
        print('⚠️ Native Google Sign-In auth error: ${e.message}');
        print('↪️ Falling back to browser OAuth...');
      } catch (e) {
        print('⚠️ Native Google Sign-In failed: $e');
        print('↪️ Falling back to browser OAuth...');
      }

      // Fallback: browser-based OAuth
      return await _browserGoogleSignIn();
    } catch (e) {
      print('❌ Google sign-in failed: $e');
      rethrow;
    }
  }

  /// Native in-app Google Sign-In using google_sign_in package
  Future<AuthResponse> _nativeGoogleSignIn() async {
    // Configure GoogleSignIn — uses Web Client ID for Supabase token exchange
    // On iOS, clientId is required (iOS OAuth Client ID or Web Client ID)
    // On Android, serverClientId is used to request the ID token
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;

    final googleSignIn = GoogleSignIn(
      // iOS needs clientId; use iOS client ID if available, fall back to Web Client ID
      clientId: isIos
          ? (Env.googleIosClientId.isNotEmpty
              ? Env.googleIosClientId
              : (Env.googleWebClientId.isNotEmpty
                  ? Env.googleWebClientId
                  : null))
          : null,
      // serverClientId is for Android to get an ID token for backend exchange
      serverClientId: Env.googleWebClientId.isNotEmpty
          ? Env.googleWebClientId
          : null,
      scopes: ['email', 'profile'],
    );

    // Sign out first to force account picker
    await googleSignIn.signOut();

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Google sign-in was cancelled by user');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw const AuthException('Failed to get Google ID token');
    }

    // Exchange the Google ID token with Supabase
    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    return response;
  }

  /// Browser-based Google OAuth (fallback)
  Future<AuthResponse> _browserGoogleSignIn() async {
    print('🔐 Starting Google OAuth browser flow...');

    final success = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'apexrun://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );

    if (!success) {
      throw const AuthException('Failed to launch Google sign-in');
    }

    print('✅ Google OAuth browser launched – waiting for redirect...');
    // Return empty response; session arrives via deep link
    return AuthResponse(session: null, user: null);
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

  /// Ensure a user profile exists after OAuth sign-in.
  /// For Google/Apple sign-ins, Supabase creates the auth.users row
  /// but the public.user_profiles row might not exist yet.
  Future<void> _ensureProfileExists(User? user) async {
    if (user == null) return;
    try {
      final existing = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        final meta = user.userMetadata;
        await _supabase.from('user_profiles').insert({
          'id': user.id,
          'display_name': meta?['full_name'] ?? meta?['name'] ?? user.email?.split('@').first ?? 'Runner',
          'avatar_url': meta?['avatar_url'] ?? meta?['picture'],
          'profile_completed': false,
        });
        print('📋 Created user profile for Google user: ${user.id}');
      }
    } catch (e) {
      // Non-fatal — profile can be created later during onboarding
      print('⚠️ Could not auto-create profile: $e');
    }
  }
}
