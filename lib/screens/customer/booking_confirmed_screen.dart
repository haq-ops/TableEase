import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'customer_main_screen.dart';

// Full screen shown after a booking (or deposit payment) is done
class BookingConfirmedScreen extends StatelessWidget {
  final String bookingId;

  const BookingConfirmedScreen({super.key, required this.bookingId});

  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Short code the guest can show at the restaurant, e.g. "#TE-7F3K2A"
  String get _reference => '#TE-${bookingId.substring(0, 6).toUpperCase()}';

  String _dateText(DateTime d) {
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final day = isToday ? 'Today' : _weekdays[d.weekday - 1];
    return '$day, ${d.day} ${_months[d.month - 1]}';
  }

  String _timeText(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // "The Gallery Café" becomes "GC"
  String _initials(String name) {
    final words = name
        .split(' ')
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'the')
        .take(2);
    return words.map((w) => w[0].toUpperCase()).join();
  }

  // Opens the customer area on a chosen tab and clears the booking screens
  void _openMain(BuildContext context, int tab) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => CustomerMainScreen(initialTab: tab),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The phone's back button goes Home instead of the booking form
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _openMain(context, 0);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
          titleSpacing: 20,
          title: Row(
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
            ],
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.border),
          ),
        ),

        // READ (live): the booking that was just made
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Could not load this booking.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!.data();
            if (data == null) {
              return const Center(child: Text('This booking was not found.'));
            }

            final name = (data['restaurantName'] ?? '').toString();
            final address = (data['address'] ?? '').toString();
            final time = (data['bookingTime'] as Timestamp).toDate();
            final guests = ((data['guests'] ?? 0) as num).toInt();
            final guestText = guests == 6
                ? '6+ People'
                : '$guests ${guests == 1 ? 'Person' : 'People'}';
            final tableType = (data['tableType'] ?? '').toString();
            final status = (data['status'] ?? '').toString();
            final paymentStatus = (data['paymentStatus'] ?? '').toString();
            final bool depositRequired = data['depositRequired'] == true;
            final bool isConfirmed = status == 'confirmed';

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 8),

                      // Big green tick
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.success,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: AppColors.success,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          paymentStatus == 'paid'
                              ? 'Payment Successful!'
                              : 'Booking Confirmed!',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text(
                          'Your table is booked.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Booking details card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reference and status
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'BOOKING REFERENCE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _reference,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                _statusChip(isConfirmed),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: 14),

                            // Restaurant
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        address,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _initials(name),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Date, time, guests, table
                            Row(
                              children: [
                                Expanded(
                                  child: _tile(
                                    Icons.calendar_today_outlined,
                                    'Date',
                                    _dateText(time),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _tile(
                                    Icons.schedule,
                                    'Time',
                                    _timeText(time),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _tile(
                                    Icons.people_outline,
                                    'Guests',
                                    guestText,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _tile(
                                    Icons.table_restaurant,
                                    'Table',
                                    tableType,
                                  ),
                                ),
                              ],
                            ),

                            // Deposit (weekend bookings only)
                            if (depositRequired) ...[
                              const SizedBox(height: 14),
                              _depositBox(paymentStatus),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Helpful note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please arrive 10 minutes early. You can change '
                                    'or cancel this booking in My Bookings.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Buttons fixed at the bottom
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: () => _openMain(context, 2),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('View My Bookings'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => _openMain(context, 0),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textDark,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Back to Home'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusChip(bool isConfirmed) {
    final Color color = isConfirmed ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
            isConfirmed ? 'Confirmed' : 'Payment pending',
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

  // Small grey box with an icon, a label and a value
  Widget _tile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
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

  Widget _depositBox(String paymentStatus) {
    final bool paid = paymentStatus == 'paid';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paid ? 'Deposit Paid (refundable)' : 'Deposit due at restaurant',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  paid
                      ? 'Deducted from your final bill at the restaurant'
                      : 'Pay Rs. 500 at the host desk when you arrive',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Rs. 500',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}