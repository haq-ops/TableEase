import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'admin_main_screen.dart';
import 'admin_requests_screen.dart';

// Screen 20: overview and analytics.
// Every number is worked out live from Firestore:
//  - Restaurants   = documents in "restaurants" (+ new this month)
//  - Bookings today = today's bookings that are not cancelled (vs yesterday)
//  - No-shows      = today's bookings that staff marked "no_show"
//  - Pending       = registrations waiting in "restaurant_requests"
//  - Busy hours    = all bookings grouped by hour, 5 PM to 10 PM
class AdminDashboardScreen extends StatefulWidget {
  final ValueChanged<int> onOpenTab;

  const AdminDashboardScreen({super.key, required this.onOpenTab});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Created once, so rebuilding the screen does not restart the streams
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _restaurantsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _bookingsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _requestsStream;

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance;
    _restaurantsStream = db.collection('restaurants').snapshots();
    _bookingsStream = db.collection('bookings').snapshots();
    _requestsStream = pendingRequestsStream();
  }

  @override
  Widget build(BuildContext context) {
    final onOpenTab = widget.onOpenTab;

    return SafeArea(
      child: Column(
        children: [
          AdminHeader(
            title: 'Dashboard',
            onBell: () => onOpenTab(2),
            onAvatar: () => onOpenTab(3),
          ),
          Expanded(
            // READ (live): restaurants, bookings and pending requests
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _restaurantsStream,
              builder: (context, restaurants) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _bookingsStream,
                  builder: (context, bookings) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _requestsStream,
                      builder: (context, requests) {
                        if (restaurants.hasError ||
                            bookings.hasError ||
                            requests.hasError) {
                          return const AdminMessage(
                            text: 'Could not load the dashboard. '
                                'Check your internet.',
                            icon: Icons.wifi_off,
                          );
                        }
                        if (!restaurants.hasData ||
                            !bookings.hasData ||
                            !requests.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return _DashboardContent(
                          restaurants: restaurants.data!.docs,
                          bookings: bookings.data!.docs,
                          requests: requests.data!.docs,
                          onOpenTab: onOpenTab,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> restaurants;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> requests;
  final ValueChanged<int> onOpenTab;

  const _DashboardContent({
    required this.restaurants,
    required this.bookings,
    required this.requests,
    required this.onOpenTab,
  });

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month);

    // Restaurants added this month (approved registrations have createdAt)
    final int newThisMonth = restaurants.where((doc) {
      final created = toDateTime(doc.data()['createdAt']);
      return created != null && !created.isBefore(monthStart);
    }).length;

    // Bookings that are not cancelled, with their date and time
    final active = <({DateTime time, String attendance})>[];
    for (final doc in bookings) {
      final data = doc.data();
      final time = toDateTime(data['bookingTime']);
      if (time == null || data['status'] == 'cancelled') continue;
      active.add((
        time: time,
        attendance: (data['attendance'] ?? '').toString(),
      ));
    }

    final today = active.where((b) => _sameDay(b.time, now)).toList();
    final int todayCount = today.length;
    final int yesterdayCount =
        active.where((b) => _sameDay(b.time, yesterday)).length;
    final int noShows = today.where((b) => b.attendance == 'no_show').length;

    // Bookings today vs yesterday
    String bookingsTrend;
    if (yesterdayCount > 0) {
      final int change =
          ((todayCount - yesterdayCount) / yesterdayCount * 100).round();
      bookingsTrend = '${change >= 0 ? '+' : ''}$change% vs yday';
    } else {
      bookingsTrend = todayCount > 0 ? 'New today' : 'No bookings yet';
    }

    // No-show rate for today
    final String noShowRate = todayCount == 0
        ? '0% rate'
        : '${(noShows / todayCount * 100).toStringAsFixed(1)}% rate';

    // Busy hours: all bookings between 5 PM and 10 PM, grouped by hour
    const hours = [17, 18, 19, 20, 21, 22];
    final counts = [
      for (final hour in hours) active.where((b) => b.time.hour == hour).length,
    ];

    // Pending requests, newest first
    final pending = requests.toList()
      ..sort((a, b) {
        final ta = toDateTime(a.data()['createdAt']);
        final tb = toDateTime(b.data()['createdAt']);
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        // Title, live badge and date
        Row(
          children: [
            const Expanded(
              child: Text(
                'Overview & Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const AdminChip(
              text: 'LIVE SYSTEM',
              icon: Icons.circle,
              background: AppColors.primaryLight,
              foreground: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 13,
              color: AppColors.textGrey,
            ),
            const SizedBox(width: 5),
            Text(
              'System summary • Today, ${adminShortDate(now)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2 x 2 stat cards
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'RESTAURANTS',
                  value: '${restaurants.length}',
                  icon: Icons.storefront_outlined,
                  iconColor: AppColors.textDark,
                  iconBackground: AppColors.surface,
                  footer: Row(
                    children: [
                      const Icon(
                        Icons.arrow_upward,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '+$newThisMonth this month',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'BOOKINGS TODAY',
                  value: '$todayCount',
                  icon: Icons.event_available_outlined,
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.primaryLight,
                  footer: AdminChip(
                    text: bookingsTrend,
                    background: AppColors.primaryLight,
                    foreground: const Color(0xFFC2410C),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'NO-SHOWS',
                  value: '$noShows',
                  icon: Icons.person_off_outlined,
                  iconColor: kRejectRed,
                  iconBackground: kRemoveRedLight,
                  footer: AdminChip(
                    text: noShowRate,
                    background: kRemoveRedLight,
                    foreground: kRemoveRed,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'PENDING',
                  value: '${pending.length}',
                  icon: Icons.hourglass_bottom,
                  iconColor: const Color(0xFFB45309),
                  iconBackground: const Color(0xFFFEF3C7),
                  footer: AdminChip(
                    text: pending.isEmpty ? 'All clear' : 'Needs review',
                    background: AppColors.surface,
                    foreground: AppColors.textGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Busy hours chart
        _BusyHoursCard(hours: hours, counts: counts),
        const SizedBox(height: 20),

        // Pending approvals
        Row(
          children: [
            const Text(
              'Pending Approvals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            if (pending.isNotEmpty)
              CircleAvatar(
                radius: 11,
                backgroundColor: AppColors.primary,
                child: Text(
                  '${pending.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => onOpenTab(2),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (pending.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.task_alt, color: kApproveGreen),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No pending approvals. You are all caught up!',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
          )
        else
          for (final request in pending.take(3)) ...[
            _ApprovalCard(
              request: request,
              onReview: () => onOpenTab(2),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 10),

        // Live sync status
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: kApproveGreen),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live sync active',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Connected to Firestore • numbers update in real time',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// One stat card, e.g. "RESTAURANTS 25 / +2 this month"
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Widget footer;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: AdminSectionLabel(label)),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: iconColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            footer,
          ],
        ),
      ),
    );
  }
}

// Bar chart of bookings per hour; the busiest hour is orange
class _BusyHoursCard extends StatelessWidget {
  final List<int> hours;
  final List<int> counts;

  const _BusyHoursCard({required this.hours, required this.counts});

  static String _hourLabel(int hour) {
    final int h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h ${hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    const double maxBarHeight = 120;
    final int maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final bool hasData = maxCount > 0;
    final int peakIndex = hasData ? counts.indexOf(maxCount) : -1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Busy Hours',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Estimated bookings (5 PM – 10 PM)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              AdminChip(
                text: hasData
                    ? 'Peak: ${_hourLabel(hours[peakIndex])}'
                    : 'No data yet',
                icon: Icons.circle,
                background: AppColors.primaryLight,
                foreground: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: maxBarHeight + 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < hours.length; i++)
                  Expanded(
                    child: Semantics(
                      label: '${_hourLabel(hours[i])}: ${counts[i]} bookings',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${counts[i]}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: i == peakIndex
                                    ? AppColors.primary
                                    : AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: hasData
                                  ? math.max(
                                      6.0,
                                      maxBarHeight * counts[i] / maxCount,
                                    )
                                  : 6.0,
                              decoration: BoxDecoration(
                                color: i == peakIndex
                                    ? AppColors.primary
                                    : const Color(0xFFE7E5E4),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _hourLabel(hours[i]),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: i == peakIndex
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: i == peakIndex
                                    ? AppColors.primary
                                    : AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// One pending registration on the dashboard, with Dismiss / Review
class _ApprovalCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> request;
  final VoidCallback onReview;

  const _ApprovalCard({required this.request, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final data = request.data();
    final String name = (data['name'] ?? 'New restaurant').toString();
    final int tables = ((data['tables'] ?? 0) as num).toInt();
    final DateTime? created = toDateTime(data['createdAt']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'New registration • $tables tables',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              if (created != null)
                Text(
                  adminTimeAgo(created),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 100,
                child: AdminButton(
                  label: 'Dismiss',
                  background: AppColors.surface,
                  foreground: AppColors.textDark,
                  onTap: () => rejectRequest(context, request),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: AdminButton(
                  label: 'Review →',
                  background: AppColors.primary,
                  foreground: Colors.white,
                  onTap: onReview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
