import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/record_screen.dart';
import '../screens/coach_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/profile_screen.dart';

/// Main Navigation with Custom Bottom Navigation Bar
///
/// Contains 5 tabs:
/// 1. Home - Dashboard with stats and recent activities
/// 2. Record - GPS tracking and activity recording (elevated center button)
/// 3. AI Coach - Gemini-powered coaching and workout plans
/// 4. Leaderboard - Segment leaderboards and competitions
/// 5. Profile - User settings and profile management
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    RecordScreen(),
    CoachScreen(),
    LeaderboardScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onTabTapped(0),
                ),
                _NavItem(
                  icon: Icons.psychology_rounded,
                  label: 'Coach',
                  isSelected: _currentIndex == 2,
                  onTap: () => _onTabTapped(2),
                ),
                // Center Record button (elevated)
                _RecordNavButton(
                  isSelected: _currentIndex == 1,
                  onTap: () => _onTabTapped(1),
                ),
                _NavItem(
                  icon: Icons.leaderboard_rounded,
                  label: 'Segments',
                  isSelected: _currentIndex == 3,
                  onTap: () => _onTabTapped(3),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
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
                color: isSelected ? AppTheme.electricLime : AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.electricLime : AppTheme.textTertiary,
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

  const _RecordNavButton({
    required this.isSelected,
    required this.onTap,
  });

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
                ? [AppTheme.electricLime, AppTheme.electricLime.withValues(alpha: 0.8)]
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
