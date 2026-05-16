import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger/app_logger.dart';

class ReferralService {
  ReferralService(this._supabase);

  final SupabaseClient _supabase;
  final _log = AppLogger.tag('Referral');

  /// Get or create the current user's referral code. Returns null when
  /// unauthenticated or on error.
  Future<String?> myCode() async {
    if (_supabase.auth.currentUser == null) return null;
    try {
      final result = await _supabase.rpc('get_or_create_referral_code');
      return (result as String?)?.toUpperCase();
    } catch (e, st) {
      _log.w('get_or_create_referral_code failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Redeem [code]. Throws with a stable error key the UI surfaces:
  ///   'invalid_code' | 'cannot_redeem_own_code' | 'already_redeemed' | 'not_authenticated'
  Future<String> redeem(String code) async {
    final cleaned = code.trim().toUpperCase();
    if (cleaned.length < 4) {
      throw const _ReferralError('invalid_code');
    }
    try {
      final result =
          await _supabase.rpc('redeem_referral_code', params: {'p_code': cleaned});
      return result as String;
    } on PostgrestException catch (e) {
      throw _ReferralError(_keyFromMessage(e.message));
    }
  }

  String _keyFromMessage(String message) {
    if (message.contains('invalid_code')) return 'invalid_code';
    if (message.contains('cannot_redeem_own_code')) return 'cannot_redeem_own_code';
    if (message.contains('already_redeemed')) return 'already_redeemed';
    if (message.contains('not authenticated')) return 'not_authenticated';
    return 'unknown';
  }

  /// Returns the public referral link the user shares.
  String shareUrlFor(String code) => 'https://apexrun.app/r/${code.toUpperCase()}';
}

class _ReferralError implements Exception {
  const _ReferralError(this.key);
  final String key;

  @override
  String toString() {
    switch (key) {
      case 'invalid_code':
        return 'Invalid referral code.';
      case 'cannot_redeem_own_code':
        return "You can't redeem your own code.";
      case 'already_redeemed':
        return 'You\'ve already redeemed a referral code.';
      case 'not_authenticated':
        return 'Please sign in first.';
      default:
        return 'Could not redeem code.';
    }
  }
}
