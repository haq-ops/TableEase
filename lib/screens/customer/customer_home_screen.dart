import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'restaurant_detail_screen.dart';
import 'book_table_screen.dart';
import 'notifications_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _firstName = '';
  String _search = '';

  // Which filter chip is selected: 'all', 'available' or 'queue'
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  // READ: gets the logged-in user's name from the "users" collection
  Future<void> _loadName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final fullName = (doc.data()?['fullName'] ?? '').toString();
    final first = fullName.split(' ').first;
    if (!mounted) return;
    setState(() {
      // Capital first letter, e.g. "amhar" becomes "Amhar"
      _firstName = first.isEmpty
          ? ''
          : first[0].toUpperCase() + first.substring(1);
    });
  }

  // Opens the Restaurant Detail screen
  void _openDetail(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailScreen(restaurantId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar: logo, app name and notification bell
          Padding(
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

                const NotificationBell(),

              ],
            ),
          ),

          // Main scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                // Greeting with the user's real first name
                Text(
                  _firstName.isEmpty ? 'Hi 👋' : 'Hi, $_firstName 👋',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Find a table or join a live waiting queue',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                const SizedBox(height: 16),

                // Rounded search box
                TextField(
                  onChanged: (value) {
                    setState(() => _search = value.trim().toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search restaurant or cuisine...',
                    fillColor: AppColors.surface,
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textGrey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Filter chips (scroll sideways)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All', Icons.star),
                      _filterChip(
                        'available',
                        'Available now',
                        Icons.check_circle_outline,
                      ),
                      _filterChip('queue', 'Join queue', Icons.schedule),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _restaurantList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // One filter chip. Orange when selected.
  Widget _filterChip(String value, String label, IconData icon) {
    final bool selected = _filter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textDark,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // READ (live): listens to the "restaurants" collection.
  // When staff change the free tables, this list updates by itself.
  Widget _restaurantList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message('Could not load restaurants. Check your internet.');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Keep only the restaurants that match the search and the filter
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final tables = ((data['tablesAvailable'] ?? 0) as num).toInt();

          if (_filter == 'available' && tables == 0) return false;
          if (_filter == 'queue' && tables > 0) return false;

          final name = (data['name'] ?? '').toString().toLowerCase();
          final address = (data['address'] ?? '').toString().toLowerCase();
          final cuisine = (data['cuisine'] ?? '').toString().toLowerCase();
          return name.contains(_search) ||
              address.contains(_search) ||
              cuisine.contains(_search);
        }).toList();

        if (docs.isEmpty) {
          return _message('No restaurants found.');
        }

        return Column(
          children: docs
              .map((doc) => _restaurantCard(doc.id, doc.data()))
              .toList(),
        );
      },
    );
  }

  // Large restaurant card with photo, tags and a Book button
  Widget _restaurantCard(String id, Map<String, dynamic> data) {
    final int tables = ((data['tablesAvailable'] ?? 0) as num).toInt();
    final int wait = ((data['waitMinutes'] ?? 0) as num).toInt();
    final String name = (data['name'] ?? '').toString();
    final String address = (data['address'] ?? '').toString();
    final String cuisine = (data['cuisine'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: GestureDetector(
        onTap: () => _openDetail(id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo with tags and button on top of it
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/restaurants/${data['image'] ?? ''}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: AppColors.surface,
                        child: const Icon(
                          Icons.restaurant,
                          size: 48,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),

                    // Status and cuisine tags on the bottom-left
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statusChip(tables, wait),
                          if (cuisine.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _whiteChip(
                              Text(
                                cuisine,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Book button on the bottom-right
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: ElevatedButton(


                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookTableScreen(
                                restaurantId: id,
                                restaurantName: name,
                                address: address,
                                cuisine: cuisine,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Book'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Name and address below the photo
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Free tables (green) or waiting time (amber), shown on the photo
  Widget _statusChip(int tables, int wait) {
    final bool hasTables = tables > 0;
    final Color color = hasTables ? AppColors.success : AppColors.warning;
    final String text = hasTables ? 'Tables: $tables' : 'Full · ~$wait min';

    return _whiteChip(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // White rounded label used on top of the photo
  Widget _whiteChip(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  // Grey message used for empty and error states
  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textGrey),
        ),
      ),
    );
  }
}