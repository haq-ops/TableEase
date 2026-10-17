import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../queue/queue_screen.dart';
import 'customer_home_screen.dart';
import 'my_bookings_screen.dart';

// Holds the 4 customer tabs and the bottom navigation bar
class CustomerMainScreen extends StatefulWidget {
  // Which tab to open first: 0 Home, 1 Queue, 2 Bookings, 3 Profile
  final int initialTab;

  const CustomerMainScreen({super.key, this.initialTab = 0});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  late int _currentTab = widget.initialTab;

  void _goToHome() => setState(() => _currentTab = 0);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const CustomerHomeScreen(),
      // Live queue (screens 13 and 14)
      QueueScreen(onGoHome: _goToHome),
      // My Bookings (screens 10 and 11)
      MyBookingsScreen(onGoHome: _goToHome),
      // Profile (screen 25)
      const ProfileScreen(),
    ];

    return Scaffold(
      // IndexedStack keeps each tab's state when switching tabs
      body: IndexedStack(index: _currentTab, children: tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textGrey,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule),
              label: 'Queue',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}