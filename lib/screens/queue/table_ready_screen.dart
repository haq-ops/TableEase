import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';


// Shown in the Queue tab when the staff say the table is ready
class TableReadyScreen extends StatelessWidget {
  final String queueId;
  final Map<String, dynamic> data;

  const TableReadyScreen({
    super.key,
    required this.queueId,
    required this.data,
  });

  // How long the customer has to reach the host stand
  static const int _minutesToArrive = 10;

  // UPDATE: the customer has seen the "table ready" message
  Future<void> _acknowledge(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('queues')
          .doc(queueId)
          .update({
        'acknowledged': true,
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ACKNOWLEDGE ERROR: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = (data['restaurantName'] ?? '').toString();
    final partySize = ((data['partySize'] ?? 1) as num).toInt();
    final queueNumber = ((data['queueNumber'] ?? 0) as num).toInt();
    final partyText = partySize == 6 ? '6+' : '$partySize';

    return Column(
      children: [
        // Top bar: logo, app name and bell
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
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
              const Icon(Icons.notifications_active, color: AppColors.primary),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // Main message
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Restaurant and party size
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$restaurantName  •  Table for $partyText',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Big green tick
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.success, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppColors.success,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Your table is ready!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 15, color: AppColors.textGrey),
                    children: [
                      TextSpan(text: 'Please come within '),
                      TextSpan(
                        text: '$_minutesToArrive minutes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Host stand notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.room_service_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Host Stand Notice',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.textGrey,
                                ),
                                children: [
                                  const TextSpan(text: 'Show your ticket '),
                                  TextSpan(
                                    text: '#$queueNumber',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                    ' to the host at the entrance '
                                        'to be seated immediately.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // OK button at the bottom
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: () => _acknowledge(context),
            child: const Text('OK'),
          ),
        ),
      ],
    );
  }
}