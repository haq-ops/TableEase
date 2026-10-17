import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : null;

// e.g. "7:30 PM"
String _timeText(DateTime d) {
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour >= 12 ? 'PM' : 'AM'}';
}

// e.g. "5 Oct"
String _dateText(DateTime d) => '${d.day} ${_months[d.month - 1]}';

// e.g. "5 min ago", "Yesterday", "2 Oct"
String _ago(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return _dateText(time);
}

// One notification in the list
class _Notice {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final DateTime time;

  const _Notice(this.icon, this.color, this.title, this.message, this.time);
}

// Turns bookings, payments and queue entries into notifications
List<_Notice> _makeNotices(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> payments,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> queues,
    ) {
  final notices = <_Notice>[];

  for (final doc in bookings) {
    final b = doc.data();
    final name = (b['restaurantName'] ?? '').toString();
    final when = _date(b['bookingTime']);
    final whenText = when == null
        ? ''
        : ' · ${_dateText(when)} at ${_timeText(when)}';
    final created = _date(b['createdAt']);
    final cancelled = _date(b['cancelledAt']);
    final status = b['status'];

    if (created != null) {
      if (status == 'pending_payment') {
        notices.add(_Notice(
          Icons.savings_outlined,
          AppColors.warning,
          'Deposit needed',
          'Pay the Rs. 500 deposit to confirm $name$whenText.',
          created,
        ));
      } else {
        notices.add(_Notice(
          Icons.event_available,
          AppColors.success,
          'Booking confirmed',
          '$name$whenText',
          created,
        ));
      }
    }
    if (status == 'cancelled' && cancelled != null) {
      notices.add(_Notice(
        Icons.event_busy,
        AppColors.danger,
        'Booking cancelled',
        '$name$whenText',
        cancelled,
      ));
    }
  }

  for (final doc in payments) {
    final p = doc.data();
    final name = (p['restaurantName'] ?? '').toString();
    final amount = ((p['amount'] ?? 0) as num).toInt();
    final created = _date(p['createdAt']);
    if (created == null) continue;

    switch (p['status']) {
      case 'paid':
        notices.add(_Notice(
          Icons.check_circle_outline,
          AppColors.success,
          'Deposit paid',
          'Rs. $amount paid for your table at $name.',
          created,
        ));
      case 'pay_at_restaurant':
        notices.add(_Notice(
          Icons.storefront,
          AppColors.warning,
          'Pay at the restaurant',
          'Please pay Rs. $amount at $name when you arrive.',
          created,
        ));
      case 'refunded':
        notices.add(_Notice(
          Icons.replay,
          Colors.blue.shade600,
          'Deposit refunded',
          'Rs. $amount for $name will be returned to you.',
          _date(p['refundedAt']) ?? created,
        ));
    }
  }

  for (final doc in queues) {
    final q = doc.data();
    final name = (q['restaurantName'] ?? '').toString();
    final number = ((q['queueNumber'] ?? 0) as num).toInt();
    final joined = _date(q['joinedAt']);
    if (joined == null) continue;

    notices.add(_Notice(
      Icons.confirmation_number_outlined,
      AppColors.primary,
      'You joined the queue',
      'Ticket #$number at $name.',
      joined,
    ));
    if (q['status'] == 'notified') {
      notices.add(_Notice(
        Icons.notifications_active,
        AppColors.success,
        'Your table is ready!',
        'Please go to the host desk at $name.',
        _date(q['notifiedAt']) ?? joined.add(const Duration(seconds: 1)),
      ));
    }
    if (q['status'] == 'seated') {
      notices.add(_Notice(
        Icons.restaurant,
        AppColors.success,
        'Enjoy your meal',
        'You have been seated at $name.',
        _date(q['seatedAt']) ?? joined.add(const Duration(seconds: 2)),
      ));
    }
  }

  // Newest first
  notices.sort((a, b) => b.time.compareTo(a.time));
  return notices;
}

// READ (live): listens to the user, bookings, payments and queues
class _NoticeBuilder extends StatelessWidget {
  final Widget Function(
      BuildContext context,
      List<_Notice> notices,
      DateTime? readAt,
      bool loading,
      ) builder;

  const _NoticeBuilder({required this.builder});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final db = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db
              .collection('bookings')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, bookingSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('payments')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, paymentSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: db
                      .collection('queues')
                      .where('userId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, queueSnap) {
                    final loading = !userSnap.hasData ||
                        !bookingSnap.hasData ||
                        !paymentSnap.hasData ||
                        !queueSnap.hasData;

                    final user = userSnap.data?.data() ?? {};
                    final clearedAt = _date(user['notificationsClearedAt']);

                    var notices = _makeNotices(
                      bookingSnap.data?.docs ?? [],
                      paymentSnap.data?.docs ?? [],
                      queueSnap.data?.docs ?? [],
                    );

                    // Hide what the user cleared
                    if (clearedAt != null) {
                      notices = notices
                          .where((n) => n.time.isAfter(clearedAt))
                          .toList();
                    }

                    return builder(
                      context,
                      notices,
                      _date(user['notificationsReadAt']),
                      loading,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// The Notifications screen
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // When the user last opened this screen (before this visit)
  DateTime? _lastRead;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  // UPDATE: everything up to now counts as read
  Future<void> _markAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      try {
        final snap = await userDoc.get();
        _lastRead = _date(snap.data()?['notificationsReadAt']);
        await userDoc.update({
          'notificationsReadAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('MARK READ ERROR: $e');
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  // UPDATE: hides every notification up to now
  Future<void> _clearAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('Your bookings and payments will not change.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'notificationsClearedAt': FieldValue.serverTimestamp(),
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Notifications cleared')),
      );
    } catch (e) {
      debugPrint('CLEAR NOTIFICATIONS ERROR: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not clear. Please try again.')),
      );
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _clearAll,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Clear all'),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _NoticeBuilder(
        builder: (context, notices, readAt, loading) {
          if (loading || !_ready) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notices.isEmpty) return _empty();

          final today = notices.where((n) => _isToday(n.time)).toList();
          final earlier = notices.where((n) => !_isToday(n.time)).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (today.isNotEmpty) ...[
                _sectionTitle('TODAY'),
                ...today.map(_tile),
                const SizedBox(height: 12),
              ],
              if (earlier.isNotEmpty) ...[
                _sectionTitle('EARLIER'),
                ...earlier.map(_tile),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF555555),
        ),
      ),
    );
  }

  // One notification card (orange when new)
  Widget _tile(_Notice n) {
    final bool isNew = _lastRead == null || n.time.isAfter(_lastRead!);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNew ? AppColors.primaryLight : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNew
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: n.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(n.icon, size: 20, color: n.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  n.message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _ago(n.time),
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
              if (isNew) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Booking, payment and queue updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}

// Bell for the Home header: shows an orange dot when something is new
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return _NoticeBuilder(
      builder: (context, notices, readAt, loading) {
        final hasNew = !loading &&
            notices.any((n) => readAt == null || n.time.isAfter(readAt));

        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none,
                color: AppColors.textDark,
              ),
              if (hasNew)
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}