import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import 'book_table_screen.dart';
import '../queue/join_queue_sheet.dart';
import 'customer_main_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  // The Firestore id of the restaurant to show
  final String restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  int _currentPhoto = 0;
  bool _showFullDescription = false;

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // Shows a short message at the bottom of the screen
  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Opens Google Maps or the phone dialer
  Future<void> _openLink(Uri uri) async {
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) _showMessage('Could not open this link.');
    } catch (e) {
      _showMessage('Could not open this link.');
    }
  }

  // Opens the Join Queue sheet. After joining, shows the Queue tab.
  Future<void> _openJoinQueue(String name, int waitMinutes) async {
    final navigator = Navigator.of(context);

    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => JoinQueueSheet(
        restaurantId: widget.restaurantId,
        restaurantName: name,
        waitMinutes: waitMinutes,
      ),
    );

    if (joined == true) {
      // Clear the screens and open the customer app on the Queue tab
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const CustomerMainScreen(initialTab: 1),
        ),
            (route) => false,
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // READ (live): listens to this one restaurant document
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(widget.restaurantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _centerText('Could not load this restaurant.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return _centerText('This restaurant is no longer available.');
          }

          final name = (data['name'] ?? '').toString();
          final address = (data['address'] ?? '').toString();
          final cuisine = (data['cuisine'] ?? '').toString();
          final price = (data['priceLevel'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final hours = (data['hours'] ?? '').toString();
          final description = (data['description'] ?? '').toString();
          final tags = List<String>.from(data['tags'] ?? []);
          final tables = ((data['tablesAvailable'] ?? 0) as num).toInt();
          final wait = ((data['waitMinutes'] ?? 0) as num).toInt();

          // Use the photo list if it exists, otherwise the single photo
          final List<String> photos =
          (data['images'] is List && (data['images'] as List).isNotEmpty)
              ? List<String>.from(data['images'])
              : [(data['image'] ?? '').toString()];

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _photoCarousel(photos),

                        // White sheet that slides over the bottom of the photo
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name and cuisine
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                if (cuisine.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    cuisine,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),

                                // Free tables or waiting time
                                _statusBadge(tables, wait),
                                const SizedBox(height: 14),

                                // Description with See more / See less
                                if (description.isNotEmpty) ...[
                                  Text(
                                    description,
                                    maxLines: _showFullDescription ? null : 3,
                                    overflow: _showFullDescription
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Color(0xFF444444),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showFullDescription =
                                        !_showFullDescription;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _showFullDescription
                                                ? 'See less'
                                                : 'See more',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          Icon(
                                            _showFullDescription
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                // Cuisine and price chips
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    if (cuisine.isNotEmpty)
                                      _infoChip(
                                        Icons.storefront,
                                        cuisine,
                                        AppColors.primaryLight,
                                      ),
                                    if (price.isNotEmpty)
                                      _infoChip(
                                        Icons.payments_outlined,
                                        price,
                                        AppColors.surface,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Address: opens Google Maps
                                _actionRow(
                                  Icons.location_on,
                                  address,
                                  'See address in Google Maps',
                                      () => _openLink(
                                    Uri.parse(
                                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
                                    ),
                                  ),
                                ),

                                // Call: opens the phone dialer
                                if (phone.isNotEmpty)
                                  _actionRow(
                                    Icons.phone,
                                    'Call restaurant',
                                    'Dial $phone directly',
                                        () => _openLink(
                                      Uri(scheme: 'tel', path: phone),
                                    ),
                                  ),
                                const SizedBox(height: 8),

                                // Feature tags
                                if (tags.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: tags.map(_tag).toList(),
                                  ),
                                const SizedBox(height: 20),

                                // Opening hours box
                                if (hours.isNotEmpty) _hoursBox(hours),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Back button on top of the photo
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: AppColors.textDark,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Buttons fixed at the bottom
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(

                          // Opens the Join Queue sheet for this restaurant
                          onPressed: () => _openJoinQueue(name, wait),

                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Join Queue'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(

                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookTableScreen(
                                  restaurantId: widget.restaurantId,
                                  restaurantName: name,
                                  address: address,
                                  cuisine: cuisine,
                                ),
                              ),
                            );
                          },

                          child: const Text('Book Table'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Swipeable photos with dots at the bottom
  Widget _photoCarousel(List<String> photos) {
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: photos.length,
            onPageChanged: (index) => setState(() => _currentPhoto = index),
            itemBuilder: (context, index) {
              return Image.asset(
                'assets/images/restaurants/${photos[index]}',
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stack) => Container(
                  color: AppColors.surface,
                  child: const Icon(
                    Icons.restaurant,
                    size: 56,
                    color: AppColors.textGrey,
                  ),
                ),
              );
            },
          ),

          // Page dots (only when there is more than one photo)
          if (photos.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(photos.length, (index) {
                  final bool active = index == _currentPhoto;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  // Green "Free tables" or amber "Full" badge
  Widget _statusBadge(int tables, int wait) {
    final bool hasTables = tables > 0;
    final Color color = hasTables ? AppColors.success : AppColors.warning;
    final String text = hasTables
        ? 'Free tables: $tables'
        : 'Full · ~$wait min wait';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Rounded chip with an icon (cuisine, price)
  Widget _infoChip(IconData icon, String text, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.textDark),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  // A tappable row with an icon, two lines of text and an arrow
  Widget _actionRow(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textDark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }

  // One grey feature tag
  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textDark),
      ),
    );
  }

  // Box listing the opening hours for each day
  Widget _hoursBox(String hours) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hours of operation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 32,
            height: 2,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          for (final day in _days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    hours,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Grey message in the middle of the screen
  Widget _centerText(String text) {
    return Center(
      child: Text(text, style: const TextStyle(color: AppColors.textGrey)),
    );
  }
}