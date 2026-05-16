import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/logger/app_logger.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/revenue_cat_service.dart';
import '../../domain/models/subscription_tier.dart';
import '../providers/app_providers.dart';

/// Apex Pro / Apex Pro+ paywall.
///
/// Pulls offerings from RevenueCat. Falls back to a "configuration pending"
/// state when RevenueCat isn't wired in this build.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  final _log = AppLogger.tag('Paywall');

  Offering? _offering;
  bool _loading = true;
  bool _purchasing = false;
  Package? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offering = await RevenueCatService.currentOffering();
      if (!mounted) return;
      setState(() {
        _offering = offering;
        _selected = offering?.availablePackages
            .firstWhere(
              (p) => p.packageType == PackageType.annual,
              orElse: () => offering.availablePackages.first,
            );
        _loading = false;
      });
    } catch (e, st) {
      _log.w('Paywall load failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = 'Could not load subscriptions. Tap retry.';
        _loading = false;
      });
    }
  }

  Future<void> _purchase() async {
    final pkg = _selected;
    if (pkg == null) return;
    setState(() => _purchasing = true);
    try {
      await RevenueCatService.purchase(pkg);
      // RevenueCat webhook will populate `subscriptions` shortly; the
      // entitlements stream picks it up automatically.
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to Apex Pro')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    try {
      await RevenueCatService.restore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchases restored')),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlements =
        ref.watch(entitlementsProvider).valueOrNull ?? Entitlements.free;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apex Pro'),
        actions: [
          Semantics(
            button: true,
            label: 'Restore prior purchases',
            child: TextButton(
              onPressed: _purchasing ? null : _restore,
              child: const Text(
                'Restore',
                style: TextStyle(color: AppTheme.electricLime),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.electricLime),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Header(currentTier: entitlements.tier),
                  const SizedBox(height: 24),
                  ..._features(),
                  const SizedBox(height: 24),
                  if (_error != null)
                    _ErrorBanner(message: _error!, onRetry: _load)
                  else if (_offering == null)
                    const _OfferingsUnavailable()
                  else
                    ..._offering!.availablePackages
                        .map((p) => _PackageTile(
                              package: p,
                              selected: identical(p, _selected),
                              onTap: () => setState(() => _selected = p),
                            ))
                        ,
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selected == null || _purchasing
                          ? null
                          : _purchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.electricLime,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _purchasing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: AppTheme.background,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              _selected == null
                                  ? 'Select a plan'
                                  : 'Start ${_selected!.storeProduct.priceString}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Subscription auto-renews until cancelled. Cancel any time in App Store / Play Store.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _features() {
    const items = [
      ('AI race plans', 'Personalized 5K → marathon plans, weekly adjusted'),
      ('Form analysis', 'Pose-based gait + injury risk on every run'),
      ('Audio coach', 'Live split + pace cues during your runs'),
      ('Streak freezes', 'Skip a day without breaking your streak'),
      ('Unlimited history', 'Every run, forever'),
      ('Premium map styles', 'Beautiful share-ready route renders'),
    ];
    return [
      for (final (title, sub) in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.electricLime,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.currentTier});
  final SubscriptionTier currentTier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.electricLime.withValues(alpha: 0.18),
            AppTheme.cardBackground,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.electricLime.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: AppTheme.electricLime,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            currentTier.isPaid ? 'You\'re on ${currentTier.displayName}' : 'Run like a scientist',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Form analysis, AI plans, and live audio coach — unlocked.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final Package package;
  final bool selected;
  final VoidCallback onTap;

  String _badge() {
    if (package.packageType == PackageType.annual) return 'BEST VALUE';
    if (package.packageType == PackageType.lifetime) return 'LIFETIME';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    final badge = _badge();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.electricLime : AppTheme.surfaceLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppTheme.electricLime : AppTheme.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (badge.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.electricLime.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: AppTheme.electricLime,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                product.priceString,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppTheme.textPrimary)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _OfferingsUnavailable extends StatelessWidget {
  const _OfferingsUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: const Text(
        'Subscription products are not configured yet. Check back after the '
        'next app update.',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}
