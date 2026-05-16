import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/config/env.dart';
import '../../core/logger/app_logger.dart';

/// Wraps RevenueCat SDK. Entitlement state is *read* from Supabase elsewhere
/// (the webhook is server of truth); this service only handles purchase flow
/// (offerings, purchase, restore).
class RevenueCatService {
  static final _log = AppLogger.tag('RC');
  static bool _initialized = false;

  /// Idempotent init. Safe to call before sign-in (uses anonymous app user id
  /// until [identify] is called with the Supabase user id).
  static Future<void> init() async {
    if (_initialized) return;
    if (!Env.isRevenueCatConfigured) {
      _log.w('RevenueCat keys not configured — purchases disabled');
      return;
    }

    String key;
    if (Platform.isIOS) {
      key = Env.revenueCatIosKey;
    } else if (Platform.isAndroid) {
      key = Env.revenueCatAndroidKey;
    } else {
      _log.w('RevenueCat not supported on this platform');
      return;
    }
    if (key.isEmpty) {
      _log.w('RevenueCat key empty for this platform');
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(key));
      _initialized = true;
      _log.i('RevenueCat initialized');
    } catch (e, st) {
      _log.w('RevenueCat init failed', error: e, stackTrace: st);
    }
  }

  /// Bind RC's app user id to the Supabase user id so the webhook can map
  /// purchases back to a row in `public.subscriptions`.
  static Future<void> identify(String supabaseUserId) async {
    if (!_initialized) return;
    try {
      await Purchases.logIn(supabaseUserId);
    } catch (e, st) {
      _log.w('RC logIn failed', error: e, stackTrace: st);
    }
  }

  static Future<void> resetOnSignOut() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
    } catch (_) {/* harmless when not signed in */}
  }

  /// Fetch the default offering. Returns null when RC is unconfigured or
  /// offerings are empty.
  static Future<Offering?> currentOffering() async {
    if (!_initialized) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (e, st) {
      _log.w('getOfferings failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Kick a purchase flow. Throws on user-visible failure modes the caller
  /// should surface (network, payment refused, configuration).
  static Future<CustomerInfo?> purchase(Package pkg) async {
    if (!_initialized) {
      throw StateError('RevenueCat not initialized');
    }
    final result = await Purchases.purchasePackage(pkg);
    return result;
  }

  static Future<CustomerInfo?> restore() async {
    if (!_initialized) return null;
    try {
      return await Purchases.restorePurchases();
    } catch (e, st) {
      _log.w('restorePurchases failed', error: e, stackTrace: st);
      return null;
    }
  }
}
