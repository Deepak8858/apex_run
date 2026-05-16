import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger/app_logger.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/deep_link_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/app_providers.dart';
import '../screens/activity_feed_screen.dart';
import '../screens/challenges_screen.dart';
import '../screens/home_screen.dart';
import '../screens/record_screen.dart';
import '../screens/profile_screen.dart';

/// Main Navigation with Custom Bottom Navigation Bar
///
/// Contains 5 tabs:
/// 1. Home - Dashboard with stats and recent activities
/// 2. Record - GPS tracking and activity recording (elevated center button)
/// 3. AI Coach - Gemini-powered coaching and workout plans
/// 4. Leaderboard - Segment leaderboards and competitions
/// 5. Profile - User settings and profile management
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  /// Tab order (Phase 5): Home / Feed / Record / Challenges / Profile.
  /// Coach + Leaderboard are reachable from Home cards and segment detail.
  final List<Widget> _screens = const [
    HomeScreen(),
    ActivityFeedScreen(),
    RecordScreen(),
    ChallengesScreen(),
    ProfileScreen(),
  ];

  StreamSubscription<DeepLinkAction>? _deepLinkSub;
  final _log = AppLogger.tag('Nav');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notif = ref.read(notificationServiceProvider);
      await notif.init();
      await ref.read(audioCoachServiceProvider).init();

      final profile = await ref.read(userProfileProvider.future);
      if (profile != null && profile.streakDays >= 3) {
        await notif.scheduleStreakWarning(currentStreak: profile.streakDays);
      }

      // Deep link subscription (referrals, friend invites, activity share).
      final deepLink = ref.read(deepLinkServiceProvider);
      await deepLink.init();
      _deepLinkSub = deepLink.stream.listen(_handleDeepLink);
    });
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  Future<void> _handleDeepLink(DeepLinkAction action) async {
    if (!mounted) return;
    switch (action.kind) {
      case DeepLinkKind.referral:
        final code = action.value!;
        try {
          await ref.read(referralServiceProvider).redeem(code);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Referral redeemed — 30 days of Apex Pro unlocked'),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
        break;
      case DeepLinkKind.activity:
        _log.i('Activity deep link ignored (no router yet): ${action.value}');
        break;
      case DeepLinkKind.challenge:
        // Switch to the Challenges tab.
        setState(() => _currentIndex = 3);
        break;
      case DeepLinkKind.friend:
        // Switch to the Feed tab (friends list lives in the feed app bar).
        setState(() => _currentIndex = 1);
        break;
    }
  }

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border(
            top: BorderSide(
              color: AppTheme.surfaceLight.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: AppLocalizations.of(context).navHome,
                  isSelected: _currentIndex == 0,
                  onTap: () => _onTabTapped(0),
                ),
                _NavItem(
                  icon: Icons.people_alt_rounded,
                  label: AppLocalizations.of(context).navFeed,
                  isSelected: _currentIndex == 1,
                  onTap: () => _onTabTapped(1),
                ),
                // Center Record button (elevated)
                _RecordNavButton(
                  isSelected: _currentIndex == 2,
                  onTap: () => _onTabTapped(2),
                ),
                _NavItem(
                  icon: Icons.flag_rounded,
                  label: AppLocalizations.of(context).navChallenges,
                  isSelected: _currentIndex == 3,
                  onTap: () => _onTabTapped(3),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: AppLocalizations.of(context).navProfile,
                  isSelected: _currentIndex == 4,
                  onTap: () => _onTabTapped(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected
                    ? AppTheme.electricLime.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected
                    ? AppTheme.electricLime
                    : AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppTheme.electricLime
                    : AppTheme.textTertiary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordNavButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _RecordNavButton({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    AppTheme.electricLime,
                    AppTheme.electricLime.withValues(alpha: 0.8),
                  ]
                : [AppTheme.surfaceLight, AppTheme.surfaceLight],
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.electricLime.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          size: 28,
          color: isSelected ? AppTheme.background : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
