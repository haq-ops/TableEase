import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../start/login_screen.dart';
import 'staff_bookings_screen.dart';
import 'staff_queue_screen.dart';
import 'staff_tables_screen.dart';
import 'staff_team_screen.dart';

// The logged-in staff member's restaurant, shared by the staff screens
class StaffSession {
  static String restaurantId = '';
  static String restaurantName = '';
  static bool isManager = false;
}

// Staff app: finds which restaurant this staff member works at,
// then shows the 4 staff tabs with a bottom navigation bar
class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen> {
  int _currentTab = 0;
  String? _restaurantId;
  String _restaurantName = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  // READ: the restaurant this staff member was added to by the manager
  // (staff_members/{email})
  Future<void> _loadRestaurant() async {
    try {
      final db = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      final email = (user?.email ?? '').trim().toLowerCase();

      if (user == null || email.isEmpty) {
        _showError('Please log in again.');
        return;
      }

      final member = await db.collection('staff_members').doc(email).get();
      if (!member.exists) {
        _showError(
          "You haven't been added to a restaurant yet. "
              'Ask your manager to add your email.',
        );
        return;
      }

      final data = member.data()!;
      final restaurantId = (data['restaurantId'] ?? '').toString();
      if (restaurantId.isEmpty) {
        _showError('Your restaurant is no longer on TableEase.');
        return;
      }

      final restaurant =
      await db.collection('restaurants').doc(restaurantId).get();
      if (!restaurant.exists) {
        _showError('Your restaurant is no longer on TableEase.');
        return;
      }

      final name = (restaurant.data()?['name'] ?? '').toString();

      // Shared with StaffHeader (Team button) and other staff screens
      StaffSession.restaurantId = restaurantId;
      StaffSession.restaurantName = name;
      StaffSession.isManager = data['role'] == 'manager';

      if (!mounted) return;
      setState(() {
        _restaurantId = restaurantId;
        _restaurantName = name;
        _error = null;
      });
    } catch (e) {
      _showError('Could not load your restaurant. Check your internet.');
    }
  }

  void _showError(String text) {
    if (!mounted) return;
    setState(() => _error = text);
  }

  Future<void> _logOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen(role: 'staff')),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = _restaurantId;

    // Still loading, or something went wrong
    if (id == null) {
      return Scaffold(
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 48,
                  color: AppColors.textGrey,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textGrey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _loadRestaurant();
                  },
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: _logOut,
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tabs = [
      // Home = live table layout (screens 15 and 16)
      StaffTablesScreen(restaurantId: id, restaurantName: _restaurantName),
      // Live waitlist (screens 18 and 19)
      StaffQueueScreen(restaurantId: id, restaurantName: _restaurantName),
      // Today's bookings (screen 17)
      StaffBookingsScreen(restaurantId: id, restaurantName: _restaurantName),
      // Same profile screen as customers (edit, logout)
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

// Top bar used on every staff tab: logo, app name, Team (managers) and bell
class StaffHeader extends StatelessWidget {
  const StaffHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/images/logo_icon.png',
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.table_restaurant,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: 'Table',
                  style: TextStyle(color: AppColors.textDark),
                ),
                TextSpan(
                  text: 'Ease',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Managers only: add or remove staff
          if (StaffSession.isManager)
            IconButton(
              tooltip: 'Team',
              icon: const Icon(
                Icons.group_outlined,
                color: AppColors.textDark,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StaffTeamScreen(
                    restaurantId: StaffSession.restaurantId,
                    restaurantName: StaffSession.restaurantName,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Alerts',
            icon: const Icon(
              Icons.notifications_none,
              color: AppColors.textDark,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new alerts')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Small grey uppercase label used above sections, e.g. "STATUS LEGEND"
class StaffSectionLabel extends StatelessWidget {
  final String text;

  const StaffSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Color(0xFF555555),
      ),
    );
  }
}

// Coloured rounded button used in staff cards (Notify, Seat Now, Arrived...)
class StaffActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const StaffActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 7:05 PM
String staffTime(DateTime time) {
  final int hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final String minute = time.minute.toString().padLeft(2, '0');
  final String period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

// Oct 06
String staffDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
}