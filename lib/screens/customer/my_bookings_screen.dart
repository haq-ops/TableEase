import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'cancel_booking_sheet.dart';
import 'change_booking_sheet.dart';
import 'payment_screen.dart';
import 'restaurant_detail_screen.dart';

// ---------- Small helpers used in this file ----------

const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime _bookingTime(Map<String, dynamic> data) =>
    (data['bookingTime'] as Timestamp).toDate();

String _timeText(DateTime d) {
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _guestText(int guests) {
  if (guests == 6) return '6+ guests';
  return '$guests ${guests == 1 ? 'guest' : 'guests'}';
}

// "Today", "Tomorrow" or "In 3 days"
String _countdown(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final days = day.difference(today).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
}

String _depositText(String paymentStatus) {
  switch (paymentStatus) {
    case 'paid':
      return 'Deposit paid';
    case 'pay_at_restaurant':
      return 'Pay deposit at restaurant';
    case 'refunded':
      return 'Deposit refunded';
    default:
      return 'Deposit not paid yet';
  }
}

// Status label and colour for a booking
(String, Color) _status(Map<String, dynamic> data) {
  final status = data['status'];
  if (status == 'cancelled') return ('Cancelled', AppColors.danger);
  if (status == 'pending_payment') return ('Payment pending', AppColors.warning);
  if (_bookingTime(data).isBefore(DateTime.now())) {
    return ('Completed', AppColors.textGrey);
  }
  return ('Confirmed', AppColors.success);
}

Widget _statusChip(String label, Color color, {bool onPhoto = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: onPhoto ? Colors.white : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ---------- Actions (shared by the cards) ----------

// UPDATE: change date, time and guests
Future<void> _changeBooking(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
    ) async {
  final messenger = ScaffoldMessenger.of(context);
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ChangeBookingSheet(bookingId: id, booking: data),
  );
  if (changed == true) {
    messenger.showSnackBar(const SnackBar(content: Text('Booking updated')));
  }
}

// UPDATE: cancel the booking (and refund the deposit if allowed)
Future<void> _cancelBooking(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
    ) async {
  final messenger = ScaffoldMessenger.of(context);
  final paymentStatus = (data['paymentStatus'] ?? '').toString();
  final minutesLeft = _bookingTime(data).difference(DateTime.now()).inMinutes;
  final bool refundable = paymentStatus == 'paid' && minutesLeft >= 60;

  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) =>
        CancelBookingSheet(booking: data, refundable: refundable),
  );
  if (reason == null) return; // The user kept the booking

  try {
    final db = FirebaseFirestore.instance;
    final paymentId = (data['paymentId'] ?? '').toString();

    await db.collection('bookings').doc(id).update({
      'status': 'cancelled',
      'cancelReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
      if (refundable) 'paymentStatus': 'refunded',
    });

    // UPDATE the payment to refunded, or DELETE an unpaid
    // "pay at restaurant" record because no money was taken
    if (paymentId.isNotEmpty) {
      final payment = db.collection('payments').doc(paymentId);
      if (refundable) {
        await payment.update({'status': 'refunded'});
      } else if (paymentStatus == 'pay_at_restaurant') {
        await payment.delete();
      }
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          refundable
              ? 'Booking cancelled. Deposit refunded.'
              : 'Booking cancelled.',
        ),
      ),
    );
  } catch (e) {
    debugPrint('CANCEL ERROR: $e');
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not cancel. Please try again.')),
    );
  }
}

// DELETE: remove a past or cancelled booking
Future<void> _removeBooking(BuildContext context, String id) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove this booking?'),
      content: const Text('It will be deleted from your booking history.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirm != true) return;

  try {
    await FirebaseFirestore.instance.collection('bookings').doc(id).delete();
    messenger.showSnackBar(const SnackBar(content: Text('Booking removed')));
  } catch (e) {
    debugPrint('REMOVE ERROR: $e');
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not remove. Please try again.')),
    );
  }
}

void _openPayment(BuildContext context, String id) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => PaymentScreen(bookingId: id)),
  );
}

// Opens the restaurant again so the user can book another table
void _bookAgain(BuildContext context, Map<String, dynamic> data) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RestaurantDetailScreen(
        restaurantId: (data['restaurantId'] ?? '').toString(),
      ),
    ),
  );
}

// ---------- The screen ----------

class MyBookingsScreen extends StatelessWidget {
  // Opens the Home tab (used on the empty screen)
  final VoidCallback onGoHome;

  const MyBookingsScreen({super.key, required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return SafeArea(
      // READ (live): all bookings of this user
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load your bookings.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Split into upcoming and past (or cancelled)
          final now = DateTime.now();
          final upcoming = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final past = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          for (final doc in snapshot.data!.docs) {
            if (doc.data()['bookingTime'] is! Timestamp) continue;
            final cancelled = doc.data()['status'] == 'cancelled';
            if (!cancelled && _bookingTime(doc.data()).isAfter(now)) {
              upcoming.add(doc);
            } else {
              past.add(doc);
            }
          }
          upcoming.sort(
                (a, b) => _bookingTime(a.data()).compareTo(_bookingTime(b.data())),
          );
          past.sort(
                (a, b) => _bookingTime(b.data()).compareTo(_bookingTime(a.data())),
          );

          return DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Bookings',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        upcoming.isEmpty
                            ? 'No upcoming tables'
                            : '${upcoming.length} upcoming '
                            '${upcoming.length == 1 ? 'table' : 'tables'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pill-shaped tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textGrey,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: [
                        Tab(height: 40, text: 'Upcoming (${upcoming.length})'),
                        const Tab(height: 40, text: 'Past'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: TabBarView(
                    children: [_upcomingList(upcoming), _pastList(past)],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _upcomingList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return _EmptyBookings(isUpcoming: true, onGoHome: onGoHome);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _sectionLabel('NEXT UP'),
        _NextUpCard(id: docs.first.id, data: docs.first.data()),
        if (docs.length > 1) ...[
          const SizedBox(height: 24),
          _sectionLabel('LATER'),
          for (final doc in docs.skip(1))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BookingCard(
                id: doc.id,
                data: doc.data(),
                isUpcoming: true,
              ),
            ),
        ],
      ],
    );
  }

  Widget _pastList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return _EmptyBookings(isUpcoming: false, onGoHome: onGoHome);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: docs.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _BookingCard(
        id: docs[i].id,
        data: docs[i].data(),
        isUpcoming: false,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: AppColors.textGrey,
        ),
      ),
    );
  }
}

// ---------- Big card for the next booking ----------

class _NextUpCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const _NextUpCard({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final time = _bookingTime(data);
    final guests = ((data['guests'] ?? 0) as num).toInt();
    final (label, color) = _status(data);
    final bool pending = data['status'] == 'pending_payment';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Photo with name, countdown and status on top
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _RestaurantPhoto(
                    restaurantId: (data['restaurantId'] ?? '').toString(),
                  ),
                  // Dark fade so the white text is easy to read
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black12, Colors.black87],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _countdown(time),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: _statusChip(label, color, onPhoto: true),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data['restaurantName'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (data['address'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Details and actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _detail(
                        Icons.calendar_today_outlined,
                        '${_weekdays[time.weekday - 1]}, ${time.day} '
                            '${_months[time.month - 1]}',
                        'Date',
                      ),
                      _detail(Icons.schedule, _timeText(time), 'Time'),
                      _detail(
                        Icons.people_outline,
                        guests == 6 ? '6+' : '$guests',
                        (data['tableType'] ?? 'Guests').toString(),
                      ),
                    ],
                  ),
                  if (data['depositRequired'] == true) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.savings_outlined,
                          size: 16,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Rs. 500 · '
                              '${_depositText((data['paymentStatus'] ?? '').toString())}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (pending) ...[
                    ElevatedButton(
                      onPressed: () => _openPayment(context, id),
                      child: const Text('Pay deposit · Rs. 500'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _changeBooking(context, id, data),
                          icon: const Icon(Icons.edit_calendar, size: 18),
                          label: const Text('Change'),
                          style: _outlined(AppColors.textDark),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelBooking(context, id, data),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Cancel'),
                          style: _outlined(AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  ButtonStyle _outlined(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(
        color: color == AppColors.textDark ? AppColors.border : color,
      ),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

// ---------- Smaller card for later and past bookings ----------

class _BookingCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool isUpcoming;

  const _BookingCard({
    required this.id,
    required this.data,
    required this.isUpcoming,
  });

  @override
  Widget build(BuildContext context) {
    final time = _bookingTime(data);
    final guests = ((data['guests'] ?? 0) as num).toInt();
    final (label, color) = _status(data);
    final bool muted = !isUpcoming;
    final bool pending = data['status'] == 'pending_payment';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date block: "SAT / 4 / Oct"
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: muted ? AppColors.surface : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _weekdays[time.weekday - 1].toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: muted ? AppColors.textGrey : AppColors.primary,
                      ),
                    ),
                    Text(
                      '${time.day}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: muted ? AppColors.textGrey : AppColors.textDark,
                      ),
                    ),
                    Text(
                      _months[time.month - 1],
                      style: TextStyle(
                        fontSize: 11,
                        color: muted ? AppColors.textGrey : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Name, status and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (data['restaurantName'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: muted
                                  ? AppColors.textGrey
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _statusChip(label, color),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _line(
                      Icons.schedule,
                      '${_timeText(time)} · ${_guestText(guests)}',
                    ),
                    const SizedBox(height: 4),
                    _line(
                      Icons.table_restaurant,
                      '${data['tableType'] ?? ''} table',
                    ),
                    if (data['depositRequired'] == true) ...[
                      const SizedBox(height: 4),
                      _line(
                        Icons.savings_outlined,
                        _depositText((data['paymentStatus'] ?? '').toString()),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),

          // Actions
          Row(
            children: isUpcoming
                ? [
              if (pending)
                _action(
                  Icons.payments_outlined,
                  'Pay',
                  AppColors.primary,
                      () => _openPayment(context, id),
                ),
              const Spacer(),
              _action(
                Icons.edit_calendar,
                'Change',
                AppColors.textDark,
                    () => _changeBooking(context, id, data),
              ),
              _action(
                Icons.close,
                'Cancel',
                AppColors.danger,
                    () => _cancelBooking(context, id, data),
              ),
            ]
                : [
              _action(
                Icons.replay,
                'Book again',
                AppColors.primary,
                    () => _bookAgain(context, data),
              ),
              const Spacer(),
              _action(
                Icons.delete_outline,
                'Remove',
                AppColors.danger,
                    () => _removeBooking(context, id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
        ),
      ],
    );
  }

  Widget _action(
      IconData icon,
      String label,
      Color color,
      VoidCallback onPressed,
      ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------- Restaurant photo (loaded from the restaurant record) ----------

class _RestaurantPhoto extends StatefulWidget {
  final String restaurantId;

  const _RestaurantPhoto({required this.restaurantId});

  @override
  State<_RestaurantPhoto> createState() => _RestaurantPhotoState();
}

class _RestaurantPhotoState extends State<_RestaurantPhoto> {
  // READ: get the restaurant once to find its photo
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _future =
  FirebaseFirestore.instance
      .collection('restaurants')
      .doc(widget.restaurantId)
      .get();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final image = (snapshot.data?.data()?['image'] ?? '').toString();
        return Image.asset(
          'assets/images/restaurants/$image',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: AppColors.surface,
            child: const Icon(
              Icons.restaurant,
              size: 40,
              color: AppColors.textGrey,
            ),
          ),
        );
      },
    );
  }
}

// ---------- Empty state ----------

class _EmptyBookings extends StatelessWidget {
  final bool isUpcoming;
  final VoidCallback onGoHome;

  const _EmptyBookings({required this.isUpcoming, required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isUpcoming ? Icons.event_available : Icons.history,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isUpcoming ? 'No upcoming bookings' : 'No past bookings yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isUpcoming
                  ? 'Find a restaurant you love and book your next table.'
                  : 'Finished and cancelled bookings will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            if (isUpcoming) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 190,
                child: ElevatedButton.icon(
                  onPressed: onGoHome,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Find a table'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}