import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/models/subscription_tier.dart';

/// Reads subscription state from the Supabase `subscriptions` table.
///
/// The actual purchase/restore/cancel flow is delegated to RevenueCat
/// (`purchases_flutter`). RevenueCat's webhook writes to Supabase via the
/// service role; this client only READS.
class SubscriptionService {
  SubscriptionService(this._supabase);

  final SupabaseClient _supabase;
  final _log = AppLogger.tag('Subs');

  /// Resolve the current user's entitlements.
  /// Returns [Entitlements.free] when unauthenticated or on any error so
  /// gates fail closed.
  Future<Entitlements> currentEntitlements() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return Entitlements.free;

    try {
      final row = await _supabase
          .from('subscriptions')
          .select('tier, status, current_period_ends_at')
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) return Entitlements.free;

      final status = row['status'] as String? ?? 'inactive';
      const activeStatuses = {'trial', 'active', 'in_grace'};
      if (!activeStatuses.contains(status)) return Entitlements.free;

      final endRaw = row['current_period_ends_at'] as String?;
      if (endRaw != null) {
        final end = DateTime.tryParse(endRaw);
        if (end != null && end.isBefore(DateTime.now())) {
          return Entitlements.free;
        }
      }

      return Entitlements(
        tier: SubscriptionTier.fromString(row['tier'] as String?),
      );
    } catch (e, st) {
      _log.w('Failed to load subscription', error: e, stackTrace: st);
      return Entitlements.free;
    }
  }

  /// Streams the subscription tier in real-time via Supabase realtime channel.
  /// Emits the latest known entitlements as RevenueCat webhook updates land.
  Stream<Entitlements> watch() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream<Entitlements>.value(Entitlements.free);
    }

    final controller = StreamController<Entitlements>();

    // Push initial value.
    currentEntitlements().then(controller.add).catchError((_) {
      controller.add(Entitlements.free);
    });

    final channel = _supabase
        .channel('subs:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (_) async {
            controller.add(await currentEntitlements());
          },
        )
        .subscribe();

    controller.onCancel = () async {
      await channel.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }
}
