/// User's product tier. Server is source of truth (Supabase `subscriptions`
/// table populated by RevenueCat webhook); the client may show a stale value
/// until the next refresh.
enum SubscriptionTier {
  free,
  pro,
  proPlus;

  /// Parse the snake_case string stored server-side.
  static SubscriptionTier fromString(String? raw) {
    switch (raw) {
      case 'pro':
        return SubscriptionTier.pro;
      case 'pro_plus':
        return SubscriptionTier.proPlus;
      case 'free':
      default:
        return SubscriptionTier.free;
    }
  }

  bool get isPaid => this != SubscriptionTier.free;
  bool get isProOrAbove => this == SubscriptionTier.pro || this == SubscriptionTier.proPlus;
  bool get isProPlus => this == SubscriptionTier.proPlus;

  String get displayName => switch (this) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.pro => 'Apex Pro',
        SubscriptionTier.proPlus => 'Apex Pro+',
      };
}

/// Capability flags resolved from tier. Add new gates here so call sites
/// stay readable (`if (entitlements.audioCoach) ...`).
class Entitlements {
  const Entitlements({required this.tier});

  final SubscriptionTier tier;

  static const Entitlements free = Entitlements(tier: SubscriptionTier.free);

  bool get audioCoach => tier.isProOrAbove;
  bool get advancedFormAnalysis => tier.isProOrAbove;
  bool get aiRacePlans => tier.isProOrAbove;
  bool get voiceCoach => tier.isProPlus;
  bool get injuryRiskPredictor => tier.isProPlus;
  bool get unlimitedHistory => tier.isProOrAbove;
  bool get streakFreezes => tier.isProOrAbove;
  bool get premiumMapStyles => tier.isProOrAbove;
  bool get unlimitedReels => tier.isProPlus;
}
