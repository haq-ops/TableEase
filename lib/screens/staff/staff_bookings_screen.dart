import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Staff "Today's Bookings" screen (Bookings tab body).
// Put this file in lib/screens/staff/ and use StaffBookingsScreen() as the
// third page in staff_main_screen.dart (replace _Placeholder('Bookings')).
// ---------------------------------------------------------------------------

enum StaffBookingStatus { upcoming, seated, noShow }

class StaffBooking {
  final String id; // e.g. "#B-101"
  final String name;
  final String timeLabel; // e.g. "7:00 PM"
  final int partySize;
  final String tableLabel; // e.g. "T4"
  StaffBookingStatus status;

  StaffBooking({
    required this.id,
    required this.name,
    required this.timeLabel,
    required this.partySize,
    required this.tableLabel,
    this.status = StaffBookingStatus.upcoming,
  });
}

enum _BookingFilter { all, upcoming, seated }

const _arrivedGreen = Color(0xFF059669);
const _noShowRed = Color(0xFFDC2626);

class StaffBookingsScreen extends StatefulWidget {
  const StaffBookingsScreen({super.key});

  @override
  State<StaffBookingsScreen> createState() => _StaffBookingsScreenState();
}

class _StaffBookingsScreenState extends State<StaffBookingsScreen> {
  // Sample data – later replace with data from Firestore.
  final List<StaffBooking> _bookings = [
    StaffBooking(
        id: '#B-101',
        name: 'Nuwan Fernando',
        timeLabel: '7:00 PM',
        partySize: 4,
        tableLabel: 'T4'),
    StaffBooking(
        id: '#B-102',
        name: 'Anura Jayasinghe',
        timeLabel: '7:30 PM',
        partySize: 2,
        tableLabel: 'T7'),
    StaffBooking(
        id: '#B-103',
        name: 'Kavindi Wickramasinghe',
        timeLabel: '8:00 PM',
        partySize: 6,
        tableLabel: 'T9'),
    StaffBooking(
        id: '#B-104',
        name: 'Rohan De Silva',
        timeLabel: '8:30 PM',
        partySize: 4,
        tableLabel: 'T2'),
  ];

  _BookingFilter _filter = _BookingFilter.all;

  int _count(StaffBookingStatus s) =>
      _bookings.where((b) => b.status == s).length;

  List<StaffBooking> get _visible {
    switch (_filter) {
      case _BookingFilter.all:
        return _bookings;
      case _BookingFilter.upcoming:
        return _bookings
            .where((b) => b.status == StaffBookingStatus.upcoming)
            .toList();
      case _BookingFilter.seated:
        return _bookings
            .where((b) => b.status == StaffBookingStatus.seated)
            .toList();
    }
  }

  String get _todayLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return 'Today, ${months[now.month - 1]} ${now.day}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _arrived(StaffBooking b) {
    setState(() => b.status = StaffBookingStatus.seated);
    // TODO: mark table b.tableLabel as Occupied and save to Firestore.
    _snack('${b.name} marked as arrived');
  }

  Future<void> _noShow(StaffBooking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Mark as no-show?'),
        content: Text(
            '${b.name}\'s booking for ${b.timeLabel} will be marked as a no-show.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('No-show', style: TextStyle(color: _noShowRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => b.status = StaffBookingStatus.noShow);
      // TODO: free table b.tableLabel and save to Firestore.
      _snack('${b.name} marked as no-show');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleRow(),
                  const SizedBox(height: 12),
                  _buildFilters(),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No bookings here',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    )
                  else
                    for (final b in list) ...[
                      _BookingCard(
                        booking: b,
                        onArrived: () => _arrived(b),
                        onNoShow: () => _noShow(b),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              children: [
                const TextSpan(
                    text: 'Table', style: TextStyle(color: Colors.black)),
                TextSpan(
                    text: 'Ease', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.notifications_none, size: 22),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Bookings",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'The Gallery Café • Colombo • $_todayLabel',
                style:
                const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD7B0)),
          ),
          child: Text(
            '• ${_count(StaffBookingStatus.upcoming)} Reserved',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final items = <_BookingFilter, String>{
      _BookingFilter.all: 'All (${_bookings.length})',
      _BookingFilter.upcoming:
      'Upcoming (${_count(StaffBookingStatus.upcoming)})',
      _BookingFilter.seated: 'Seated (${_count(StaffBookingStatus.seated)})',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in items.entries) ...[
            GestureDetector(
              onTap: () => setState(() => _filter = e.key),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _filter == e.key
                      ? AppColors.primary
                      : const Color(0xFFF0F1F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _filter == e.key ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final StaffBooking booking;
  final VoidCallback onArrived;
  final VoidCallback onNoShow;

  const _BookingCard({
    required this.booking,
    required this.onArrived,
    required this.onNoShow,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = booking.status == StaffBookingStatus.noShow;
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            booking.id,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textGrey),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              booking.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 12, color: AppColors.textGrey),
                          const SizedBox(width: 4),
                          Text(
                            booking.timeLabel,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textGrey),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('•',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textGrey)),
                          ),
                          const Icon(Icons.people_outline,
                              size: 13, color: AppColors.textGrey),
                          const SizedBox(width: 4),
                          Text(
                            '${booking.partySize} People',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Text(
                    'Table ${booking.tableLabel}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    switch (booking.status) {
      case StaffBookingStatus.upcoming:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onArrived,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _arrivedGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Arrived',
                    style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onNoShow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _noShowRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('No-show',
                    style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );
      case StaffBookingStatus.seated:
        return _statusBanner(
          icon: Icons.check_circle,
          text: 'Seated',
          color: _arrivedGreen,
        );
      case StaffBookingStatus.noShow:
        return _statusBanner(
          icon: Icons.cancel,
          text: 'No-show',
          color: _noShowRed,
        );
    }
  }

  Widget _statusBanner({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}