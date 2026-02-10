import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/record_screen.dart';
import '../screens/coach_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/profile_screen.dart';

/// Main Navigation with Bottom Navigation Bar
///
/// Contains 5 tabs:
/// 1. Home - Dashboard with stats and recent activities
/// 2. Record - GPS tracking and activity recording
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_rounded),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_rounded),
            label: 'Coach',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_rounded),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
