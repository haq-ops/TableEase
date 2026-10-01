import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Bottom sheet that asks the user to confirm a cancellation.
// Returns the chosen reason, or null if the user keeps the booking.
class CancelBookingSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final bool refundable;

  const CancelBookingSheet({
    super.key,
    required this.booking,
    required this.refundable,
  });

  @override
  State<CancelBookingSheet> createState() => _CancelBookingSheetState();
}

class _CancelBookingSheetState extends State<CancelBookingSheet> {
  static const List<String> _reasons = [
    'Change of plans',
    'Booked by mistake',
    'Found another place',
    'Running late',
    'Other',
  ];
  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String? _reason;

  String _timeText(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final time = (b['bookingTime'] as Timestamp).toDate();
    final guests = ((b['guests'] ?? 0) as num).toInt();
    final guestText = guests == 6
        ? '6+ guests'
        : '$guests ${guests == 1 ? 'guest' : 'guests'}';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
            const SizedBox(height: 20),

            // Red icon and title
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy,
                  color: AppColors.danger,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Cancel this booking?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'This table will be released for other diners.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ),
            const SizedBox(height: 18),

            // Booking summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (b['restaurantName'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_weekdays[time.weekday - 1]}, ${time.day} '
                        '${_months[time.month - 1]} · ${_timeText(time)} · $guestText',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _refundBox(),
            const SizedBox(height: 18),

            // Optional reason
            const Text(
              'WHY ARE YOU CANCELLING? (OPTIONAL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF555555),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map(_reasonChip).toList(),
            ),
            const SizedBox(height: 22),

            // Buttons
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _reason ?? 'Not given'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('Yes, cancel booking'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textDark,
                minimumSize: const Size(double.infinity, 46),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Keep my booking'),
            ),
          ],
        ),
      ),
    );
  }

  // Green (refund), amber (no refund) or grey (no deposit) message
  Widget _refundBox() {
    final paymentStatus = (widget.booking['paymentStatus'] ?? '').toString();

    Color color = AppColors.textGrey;
    IconData icon = Icons.check_circle_outline;
    String title = 'No charge to cancel';
    String text = 'No deposit was taken for this booking.';

    if (paymentStatus == 'paid' && widget.refundable) {
      color = AppColors.success;
      icon = Icons.verified_outlined;
      title = 'Rs. 500 deposit will be refunded';
      text = 'The refund goes back to your original payment method.';
    } else if (paymentStatus == 'paid') {
      color = AppColors.warning;
      icon = Icons.info_outline;
      title = 'Deposit cannot be refunded';
      text = 'Less than 1 hour is left before your booking.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonChip(String reason) {
    final bool selected = _reason == reason;

    return GestureDetector(
      onTap: () => setState(() => _reason = selected ? null : reason),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          reason,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? AppColors.primary : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}