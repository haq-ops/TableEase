import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../start/splash_screen.dart';
import 'customer_home_screen.dart';
import 'my_bookings_screen.dart';

// Holds the 4 customer tabs and the bottom navigation bar.
// Queue and Profile tabs will show Kokulayasan's screens.
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
      // Placeholder until the Queue screen is merged
      _EmptyState(
        icon: Icons.schedule,
        title: 'You are not in any queue',
        message: 'Find a restaurant on the Home tab and join its live queue.',
        buttonText: 'Go to Home',
        onPressed: _goToHome,
      ),
      // My Bookings (screens 10 and 11)
      MyBookingsScreen(onGoHome: _goToHome),
      // Placeholder until the Profile screen is merged
      const _ProfileTab(),
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

// Friendly screen shown when a tab has nothing to show yet
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple logout tab, used until the Profile screen is merged
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    // Clear all screens and go back to the start
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user?.email ?? '',
              style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => _logout(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}