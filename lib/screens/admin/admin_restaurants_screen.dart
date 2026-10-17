import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'admin_main_screen.dart';

// Screens 23 and 24: all partner restaurants.
// Search, filter by city, edit details, or remove a restaurant
// (with the confirmation popup from screen 24).
class AdminRestaurantsScreen extends StatefulWidget {
  final ValueChanged<int> onOpenTab;

  const AdminRestaurantsScreen({super.key, required this.onOpenTab});

  @override
  State<AdminRestaurantsScreen> createState() => _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState extends State<AdminRestaurantsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _city = 'All';

  // Created once, so typing in the search box does not restart the stream
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _restaurantsStream;

  @override
  void initState() {
    super.initState();
    _restaurantsStream =
        FirebaseFirestore.instance.collection('restaurants').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminHeader(
            onBell: () => widget.onOpenTab(2),
            onAvatar: () => widget.onOpenTab(3),
          ),
          Expanded(
            // READ (live): every restaurant
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _restaurantsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const AdminMessage(
                    text: 'Could not load restaurants. Check your internet.',
                    icon: Icons.wifi_off,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // A to Z by name
                final restaurants = snapshot.data!.docs.toList()
                  ..sort((a, b) => _name(a).compareTo(_name(b)));

                return _content(restaurants);
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _name(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return (doc.data()['name'] ?? '').toString();
  }

  static String _cityOfDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return cityOf((doc.data()['address'] ?? '').toString());
  }

  Widget _content(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> restaurants,
  ) {
    final counts = cityCounts(restaurants.map(_cityOfDoc));
    final String city = counts.containsKey(_city) ? _city : 'All';
    final String query = _query.toLowerCase();

    final shown = restaurants.where((doc) {
      if (city != 'All' && _cityOfDoc(doc) != city) return false;
      if (query.isEmpty) return true;
      final data = doc.data();
      final text = '${data['name'] ?? ''} ${data['cuisine'] ?? ''} '
              '${data['address'] ?? ''}'
          .toLowerCase();
      return text.contains(query);
    }).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        // Title and active count
        Row(
          children: [
            const Expanded(
              child: Text(
                'Restaurants',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            AdminChip(
              text: '${restaurants.length} Active',
              background: const Color(0xFFFEF3C7),
              foreground: const Color(0xFFB45309),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage partner listings & dining venues',
          style: TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        const SizedBox(height: 14),

        // Search box
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search restaurants',
            prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, color: AppColors.textGrey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // City filter
        AdminFilterChips(
          counts: counts,
          total: restaurants.length,
          selected: city,
          onSelected: (value) => setState(() => _city = value),
        ),
        const SizedBox(height: 14),

        if (shown.isEmpty)
          AdminMessage(
            text: restaurants.isEmpty
                ? 'No restaurants yet.'
                : 'No restaurants match "$_query".',
            icon: Icons.search_off,
          )
        else
          for (final restaurant in shown) ...[
            _RestaurantCard(restaurant: restaurant),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

// One restaurant with Edit / Remove
class _RestaurantCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> restaurant;

  const _RestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final data = restaurant.data();
    final String name = (data['name'] ?? 'Unnamed').toString();
    final String address = (data['address'] ?? '').toString();
    final String hours = (data['hours'] ?? '').toString();
    final String owner = (data['owner'] ?? '').toString();
    final String priceLevel = (data['priceLevel'] ?? '').toString();
    final num? rating = data['rating'] is num ? data['rating'] as num : null;
    final int free = ((data['tablesAvailable'] ?? 0) as num).toInt();
    final int? total =
        data['totalTables'] is num ? (data['totalTables'] as num).toInt() : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminInitialsBox(name: name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            hours.isEmpty
                                ? areaOf(address)
                                : '${areaOf(address)} • $hours',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AdminChip(
                text: total != null ? '$total Tables' : '$free Free',
                background: AppColors.surface,
                foreground: AppColors.textGrey,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Owner and rating / price level
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Owner: ${owner.isEmpty ? 'Not set' : owner}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  rating != null
                      ? 'Rating: ★ ${rating.toStringAsFixed(1)}'
                      : 'Price: $priceLevel',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Edit / Remove
          Row(
            children: [
              Expanded(
                child: AdminButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  background: AppColors.background,
                  foreground: AppColors.textDark,
                  borderColor: AppColors.border,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.background,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (sheetContext) =>
                        _EditRestaurantSheet(restaurant: restaurant),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminButton(
                  label: 'Remove',
                  icon: Icons.delete_outline,
                  background: kRemoveRedLight,
                  foreground: kRemoveRed,
                  borderColor: kRemoveRed.withValues(alpha: 0.25),
                  onTap: () => confirmRemoveRestaurant(context, restaurant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// UPDATE: edit a restaurant's main details
class _EditRestaurantSheet extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> restaurant;

  const _EditRestaurantSheet({required this.restaurant});

  @override
  State<_EditRestaurantSheet> createState() => _EditRestaurantSheetState();
}

class _EditRestaurantSheetState extends State<_EditRestaurantSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _owner;
  late final TextEditingController _cuisine;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _hours;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.restaurant.data();
    String text(String key) => (data[key] ?? '').toString();

    _name = TextEditingController(text: text('name'));
    _owner = TextEditingController(text: text('owner'));
    _cuisine = TextEditingController(text: text('cuisine'));
    _address = TextEditingController(text: text('address'));
    _phone = TextEditingController(text: text('phone'));
    _hours = TextEditingController(text: text('hours'));
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _owner,
      _cuisine,
      _address,
      _phone,
      _hours,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await widget.restaurant.reference.update({
        'name': _name.text.trim(),
        'owner': _owner.text.trim(),
        'cuisine': _cuisine.text.trim(),
        'address': _address.text.trim(),
        'city': cityOf(_address.text.trim()),
        'phone': _phone.text.trim(),
        'hours': _hours.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${_name.text.trim()} updated.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _required(String? value) {
    return (value == null || value.trim().isEmpty)
        ? 'This field is required'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Moves the sheet up when the keyboard opens
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Restaurant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              _field('RESTAURANT NAME', _name, validator: _required),
              _field('OWNER NAME', _owner),
              _field('CUISINE', _cuisine, validator: _required),
              _field('ADDRESS', _address, validator: _required),
              _field(
                'PHONE NUMBER',
                _phone,
                keyboardType: TextInputType.phone,
              ),
              _field('OPENING HOURS', _hours),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionLabel(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: TextCapitalization.words,
            validator: validator,
            decoration: const InputDecoration(),
          ),
        ],
      ),
    );
  }
}

// Screen 24: "Remove this restaurant?" popup.
// Yes -> the restaurant and its tables are deleted, and its upcoming
// bookings are cancelled so customers are not left with a dead booking.
Future<void> confirmRemoveRestaurant(
  BuildContext context,
  DocumentSnapshot<Map<String, dynamic>> restaurant,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final String name = (restaurant.data()?['name'] ?? 'this restaurant')
      .toString();

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: kRemoveRedLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: kRemoveRed,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Remove this restaurant?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textGrey,
                ),
                children: [
                  const TextSpan(text: 'Are you sure you want to remove '),
                  TextSpan(
                    text: '"$name"',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const TextSpan(
                    text: '? This will delist their tables and active '
                        'reservations.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDark,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'No',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRemoveRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Yes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (confirmed != true) return;

  try {
    await _removeRestaurant(restaurant.reference);
    messenger.showSnackBar(SnackBar(content: Text('"$name" was removed.')));
  } catch (e) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not remove. Please try again.')),
    );
  }
}

// DELETE: the restaurant, its tables, and cancel its upcoming bookings
Future<void> _removeRestaurant(
  DocumentReference<Map<String, dynamic>> restaurantRef,
) async {
  final db = FirebaseFirestore.instance;
  final now = DateTime.now();

  final bookings = await db
      .collection('bookings')
      .where('restaurantId', isEqualTo: restaurantRef.id)
      .get();
  final tables = await restaurantRef.collection('tables').get();

  final batch = db.batch();

  for (final booking in bookings.docs) {
    final data = booking.data();
    final time = toDateTime(data['bookingTime']);
    final bool upcoming = time == null || time.isAfter(now);
    if (data['status'] != 'cancelled' && upcoming) {
      batch.update(booking.reference, {
        'status': 'cancelled',
        'cancelReason': 'Restaurant removed from TableEase',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    }
  }
  for (final table in tables.docs) {
    batch.delete(table.reference);
  }
  batch.delete(restaurantRef);

  await batch.commit();
}
