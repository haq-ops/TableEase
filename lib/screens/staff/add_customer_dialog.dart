import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// What the dialog returns when the user taps Save.
class AddCustomerResult {
  final String name;
  final String phone;
  final int partySize;

  const AddCustomerResult({
    required this.name,
    required this.phone,
    required this.partySize,
  });
}

/// Usage:
///   final result = await showDialog<AddCustomerResult>(
///     context: context,
///     builder: (_) => const AddCustomerDialog(),
///   );
class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  static const _sizes = [2, 4, 6, 8]; // 8 is shown as "8+"
  static const _fieldFill = Color(0xFFFEF6F2);
  static const _fieldBorder = Color(0xFFFBE3D6);
  static const _greyBtn = Color(0xFFEFEDEC);

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  int _size = 4;
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter the customer name');
      return;
    }
    Navigator.pop(
      context,
      AddCustomerResult(
        name: name,
        phone: _phoneCtrl.text.trim(),
        partySize: _size,
      ),
    );
  }

  InputDecoration _decoration(String hint, {String? errorText}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      filled: true,
      fillColor: _fieldFill,
      hintStyle: const TextStyle(color: Color(0xFFB8B8BE), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(_fieldBorder),
      enabledBorder: border(_fieldBorder),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(const Color(0xFFEF4444)),
      focusedErrorBorder: border(const Color(0xFFEF4444)),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + close button
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add Customer',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F0EF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEFEDEC)),
            const SizedBox(height: 18),

            // Customer name
            _label('Customer Name'),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration:
              _decoration('e.g., Nuwan Fernando', errorText: _nameError),
            ),
            const SizedBox(height: 16),

            // Phone number
            _label('Phone Number'),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _decoration('+94 77 123 4567'),
            ),
            const SizedBox(height: 16),

            // Number of people
            _label('Number of People'),
            Row(
              children: [
                for (var i = 0; i < _sizes.length; i++) ...[
                  Expanded(child: _sizeChip(_sizes[i])),
                  if (i != _sizes.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Cancel / Save
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _greyBtn,
                      foregroundColor: Colors.black87,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sizeChip(int value) {
    final selected = _size == value;
    return GestureDetector(
      onTap: () => setState(() => _size = value),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : _greyBtn,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          value == 8 ? '8+' : '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}