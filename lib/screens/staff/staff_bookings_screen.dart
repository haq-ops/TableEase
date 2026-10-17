import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'staff_main_screen.dart';

// Screen 17: today's bookings for this restaurant.
// Reads the same "bookings" documents customers create in BookTableScreen.
// Arrived / No-show are saved in a separate "attendance" field, so the
// booking's own status (confirmed, pending_payment...) is not changed.
class StaffBookingsScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const StaffBookingsScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<StaffBookingsScreen> createState() => _StaffBookingsScreenState();
}

class _StaffBookingsScreenState extends State<StaffBookingsScreen> {
  // 'all', 'upcoming' (not marked yet) or 'seated' (arrived)
  String _tab = 'all';

  // Customer names, loaded once per customer
  final Map<String, Future<String>> _names = {};

  CollectionReference<Map<String, dynamic>> get _bookings =>
      FirebaseFirestore.instance.collection('bookings');

  // READ: the customer's name from the "users" collection
  Future<String> _nameOf(String userId) {
    return _names.putIfAbsent(userId, () async {
      if (userId.isEmpty) return 'Guest';
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final name = (doc.data()?['fullName'] ?? '').toString().trim();
      return name.isEmpty ? 'Guest' : name;
    });
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // UPDATE: the guest has arrived
  Future<void> _markArrived(_Booking booking) async {
    try {
      await _bookings.doc(booking.id).update({
        'attendance': 'arrived',
        'arrivedAt': FieldValue.serverTimestamp(),
      });
      _showMessage('Marked as arrived.');
    } catch (e) {
      _showMessage('Could not update. Check your internet.');
    }
  }

  // UPDATE: the guest did not come (asks first)
  Future<void> _markNoShow(_Booking booking) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as no-show?'),
        content: Text(
          'Booking ${booking.code} at ${staffTime(booking.time)} '
              'will be marked as a no-show.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'No-show',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _bookings.doc(booking.id).update({
        'attendance': 'no_show',
        'noShowAt': FieldValue.serverTimestamp(),
      });
      _showMessage('Marked as no-show.');
    } catch (e) {
      _showMessage('Could not update. Check your internet.');
    }
  }

  // UPDATE: undo Arrived or No-show
  Future<void> _undo(_Booking booking) async {
    try {
      await _bookings.doc(booking.id).update({
        'attendance': FieldValue.delete(),
      });
    } catch (e) {
      _showMessage('Could not update. Check your internet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffHeader(),
          Expanded(
            // READ (live): every booking for this restaurant
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _bookings
                  .where('restaurantId', isEqualTo: widget.restaurantId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    'Could not load bookings. Check your internet.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Keep today's bookings that were not cancelled
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final tomorrowStart = todayStart.add(const Duration(days: 1));

                final today = snapshot.data!.docs
                    .map((doc) => _Booking.fromDoc(doc))
                    .where((b) =>
                b.status != 'cancelled' &&
                    !b.time.isBefore(todayStart) &&
                    b.time.isBefore(tomorrowStart))
                    .toList()
                  ..sort((a, b) => a.time.compareTo(b.time));

                final upcoming =
                today.where((b) => b.attendance.isEmpty).toList();
                final seated =
                today.where((b) => b.attendance == 'arrived').toList();

                final shown = _tab == 'upcoming'
                    ? upcoming
                    : _tab == 'seated'
                    ? seated
                    : today;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    _titleRow(today.length, now),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _tabChip('all', 'All (${today.length})'),
                          _tabChip('upcoming', 'Upcoming (${upcoming.length})'),
                          _tabChip('seated', 'Seated (${seated.length})'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (shown.isEmpty)
                      _message(
                        today.isEmpty
                            ? 'No bookings for today yet.'
                            : 'Nothing in this list.',
                      )
                    else
                      ...shown.map(_bookingCard),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // "Today's Bookings" title, date and reserved count
  Widget _titleRow(int count, DateTime now) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Today's Bookings",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '• $count Reserved',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.restaurantName} • Today, ${staffDate(now)}',
          style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
      ],
    );
  }

  Widget _tabChip(String value, String label) {
    final bool selected = _tab == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  // One booking card
  Widget _bookingCard(_Booking booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Booking code and customer name
                    Row(
                      children: [
                        Text(
                          booking.code,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: _nameOf(booking.userId),
                            builder: (context, snapshot) => Text(
                              snapshot.data ?? '…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Time and party size
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          staffTime(booking.time),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                          ),
                        ),
                        const Text(
                          '  •  ',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${booking.guests} People',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    if (booking.status == 'pending_payment') ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Deposit not paid yet',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Table type chosen by the customer
              if (booking.tableType.isNotEmpty)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    booking.tableType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Buttons, or the result after marking
          if (booking.attendance.isEmpty)
            Row(
              children: [
                Expanded(
                  child: StaffActionButton(
                    label: 'Arrived',
                    icon: Icons.check,
                    background: AppColors.success,
                    foreground: Colors.white,
                    onTap: () => _markArrived(booking),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StaffActionButton(
                    label: 'No-show',
                    icon: Icons.close,
                    background: AppColors.danger,
                    foreground: Colors.white,
                    onTap: () => _markNoShow(booking),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  booking.attendance == 'arrived'
                      ? Icons.check_circle
                      : Icons.cancel,
                  size: 18,
                  color: booking.attendance == 'arrived'
                      ? AppColors.success
                      : AppColors.danger,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking.attendance == 'arrived' ? 'Arrived' : 'No-show',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: booking.attendance == 'arrived'
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _undo(booking),
                  child: const Text(
                    'Undo',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

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

// One booking, read from the fields BookTableScreen writes
class _Booking {
  final String id;
  final String code;
  final String userId;
  final DateTime time;
  final int guests;
  final String tableType;
  final String status;
  final String attendance;

  _Booking({
    required this.id,
    required this.code,
    required this.userId,
    required this.time,
    required this.guests,
    required this.tableType,
    required this.status,
    required this.attendance,
  });

  factory _Booking.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final when = data['bookingTime'];
    final String shortId = doc.id.length >= 4
        ? doc.id.substring(doc.id.length - 4).toUpperCase()
        : doc.id.toUpperCase();

    return _Booking(
      id: doc.id,
      code: '#B-$shortId',
      userId: (data['userId'] ?? '').toString(),
      time: when is Timestamp ? when.toDate() : DateTime(2000),
      guests: ((data['guests'] ?? 1) as num).toInt(),
      tableType: (data['tableType'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      attendance: (data['attendance'] ?? '').toString(),
    );
  }
}
