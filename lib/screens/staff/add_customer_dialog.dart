import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Screen 19: staff adds a walk-in customer to the live queue.
// Creates the same kind of "queues" document as the customer app,
// with source 'walk_in' and no userId (the guest has no account).
// Returns true when the customer was added.
class AddCustomerDialog extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const AddCustomerDialog({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  int _partySize = 2;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // CREATE: add the walk-in customer to the end of today's queue
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final queues = FirebaseFirestore.instance.collection('queues');

      // READ: today's highest queue number at this restaurant
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final restaurantQueue = await queues
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .get();
      int highest = 0;
      for (final doc in restaurantQueue.docs) {
        final joined = doc.data()['joinedAt'] as Timestamp?;
        final isToday = joined == null || !joined.toDate().isBefore(todayStart);
        final number = ((doc.data()['queueNumber'] ?? 0) as num).toInt();
        if (isToday && number > highest) highest = number;
      }

      await queues.add({
        'customerName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'restaurantId': widget.restaurantId,
        'restaurantName': widget.restaurantName,
        'queueNumber': highest + 1,
        'partySize': _partySize,
        'status': 'waiting',
        'source': 'walk_in',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not add the customer. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and close button
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Customer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: AppColors.textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer name
                    _label('Customer Name'),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Nuwan Fernando',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the customer name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Phone number
                    _label('Phone Number'),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '+94 77 123 4567',
                      ),
                      validator: (value) {
                        final digits = (value ?? '').replaceAll(
                          RegExp(r'[^0-9]'),
                          '',
                        );
                        if (digits.length < 9) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Party size
                    _label('Number of People'),
                    Row(
                      children: [
                        _sizeOption(2, '2'),
                        const SizedBox(width: 8),
                        _sizeOption(4, '4'),
                        const SizedBox(width: 8),
                        _sizeOption(6, '6'),
                        const SizedBox(width: 8),
                        _sizeOption(8, '8+'),
                      ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Cancel and Save
                    Row(
                      children: [
                        Expanded(
                          child: _button(
                            label: 'Cancel',
                            background: AppColors.surface,
                            foreground: AppColors.textDark,
                            onTap: _isSaving
                                ? null
                                : () => Navigator.pop(context, false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _button(
                            label: 'Save',
                            background: AppColors.primary,
                            foreground: Colors.white,
                            loading: _isSaving,
                            onTap: _isSaving ? null : _save,
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
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  // One party size box (orange when selected)
  Widget _sizeOption(int value, String label) {
    final bool selected = _partySize == value;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label people',
        child: GestureDetector(
          onTap: () => setState(() => _partySize = value),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Rounded button that also shows a spinner while saving
  Widget _button({
    required String label,
    required Color background,
    required Color foreground,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: loading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: foreground,
              ),
            )
                : Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
