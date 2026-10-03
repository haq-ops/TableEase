import 'package:flutter/material.dart';
import 'staff_tables_screen.dart';
import 'staff_queue_screen.dart';

class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen> {
  int _index = 0;

  final List<Widget> _tabs = const [
    StaffTablesScreen(),
    StaffQueueScreen(),
    _Placeholder('Bookings'),
    _Placeholder('Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.access_time),
              activeIcon: Icon(Icons.access_time_filled),
              label: 'Queue'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Bookings'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Center(child: Text(title)));
  }
}