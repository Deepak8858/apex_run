import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/logger/app_logger.dart';

/// Authentication Data Source using Supabase
///
/// All log statements MUST avoid PII (email, user IDs, tokens).
/// The shared logger redacts known patterns but is best-effort only.
class AuthDataSource {
  AuthDataSource(this._supabase);

  final SupabaseClient _supabase;
  final _log = AppLogger.tag('Auth');

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  bool get isAuthenticated => currentSession != null && currentUser != null;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _log.i('Email sign-in started');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _log.i('Email sign-in success');
      return response;
    } catch (e, st) {
      _log.e('Email sign-in failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _log.i('Email sign-up started');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      _log.i('Email sign-up success (session=${response.session != null})');
      return response;
    } catch (e, st) {
      _log.e('Email sign-up failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Sign in with Google — native in-app flow, browser fallback on failure.
  Future<AuthResponse> signInWithGoogle() async {
    try {
      _log.i('Google sign-in started (native)');
      try {
        final response = await _nativeGoogleSignIn();
        if (response.session != null) {
          _log.i('Google sign-in success (native)');
          await _ensureProfileExists(response.user);
          return response;
        }
      } on PlatformException catch (e) {
        _log.w('Native Google sign-in unavailable; falling back to browser', error: e);
      } on AuthException catch (e) {
        if (e.message.contains('cancelled')) rethrow;
        _log.w('Native Google sign-in auth error; falling back to browser', error: e);
      } catch (e) {
        _log.w('Native Google sign-in failed; falling back to browser', error: e);
      }

      return await _browserGoogleSignIn();
    } catch (e, st) {
      _log.e('Google sign-in failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<AuthResponse> _nativeGoogleSignIn() async {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;

    final googleSignIn = GoogleSignIn(
      clientId: isIos
          ? (Env.googleIosClientId.isNotEmpty
              ? Env.googleIosClientId
              : (Env.googleWebClientId.isNotEmpty ? Env.googleWebClientId : null))
          : null,
      serverClientId: Env.googleWebClientId.isNotEmpty ? Env.googleWebClientId : null,
      scopes: const ['email', 'profile'],
    );

    await googleSignIn.signOut(); // force account picker

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

    return _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<AuthResponse> _browserGoogleSignIn() async {
    _log.i('Google OAuth browser flow started');
    final success = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'apexrun://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!success) {
      throw const AuthException('Failed to launch Google sign-in');
    }
    _log.i('Google OAuth browser launched; awaiting redirect');
    return AuthResponse(session: null, user: null);
  }

  Future<AuthResponse> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Failed to get Apple ID token');
    }

    return _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  Future<void> signOut() async => _supabase.auth.signOut();

  Future<void> resetPassword({required String email}) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'apexrun://reset-password',
    );
  }

  Future<UserResponse> updatePassword({required String newPassword}) async {
    return _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<UserResponse> updateUserMetadata({
    required Map<String, dynamic> metadata,
  }) async {
    return _supabase.auth.updateUser(UserAttributes(data: metadata));
  }

  Future<AuthResponse> refreshSession() async {
    return _supabase.auth.refreshSession();
  }

  /// Permanently delete the current user account.
  ///
  /// Invokes a Supabase Edge Function `delete-account` that:
  ///   1. Verifies the caller's JWT (must match `user_id` of the row to delete).
  ///   2. Soft-deletes all owned rows (activities, segment_efforts, planned_workouts,
  ///      user_profiles, friendships, etc.) — schedules a 30-day hard purge.
  ///   3. Calls `supabase.auth.admin.deleteUser(uid)` server-side.
  ///   4. Returns 204 on success.
  ///
  /// The client then signs out locally; no further requests will succeed.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Not signed in');
    }
    _log.w('Account deletion requested');
    try {
      await _supabase.functions.invoke('delete-account');
      _log.w('Account deletion server call returned OK');
      await _supabase.auth.signOut();
    } catch (e, st) {
      _log.e('Account deletion failed', error: e, stackTrace: st);
      rethrow;
    }
  }

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
        _log.i('Auto-created user profile after OAuth');
      }
    } catch (e, st) {
      _log.w('Could not auto-create profile (non-fatal)', error: e, stackTrace: st);
    }
  }
}
