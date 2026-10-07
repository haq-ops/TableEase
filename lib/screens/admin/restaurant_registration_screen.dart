import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../start/login_screen.dart';
import 'admin_main_screen.dart';

// Screen 21: a restaurant owner registers their restaurant.
// The form creates a "pending" document in restaurant_requests.
// The admin reviews it on the Requests tab (screen 22).
//
// Note: we are on the Firebase Spark plan (no Storage), so only the
// verification document's file name is saved, not the file itself.
class RestaurantRegistrationScreen extends StatefulWidget {
  const RestaurantRegistrationScreen({super.key});

  @override
  State<RestaurantRegistrationScreen> createState() =>
      _RestaurantRegistrationScreenState();
}

class _RestaurantRegistrationScreenState
    extends State<RestaurantRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _ownerController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _tablesController = TextEditingController();

  String? _documentName;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cuisineController.dispose();
    _ownerController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _tablesController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Pick a photo of the BR certificate / food licence
  Future<void> _pickDocument() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (file == null) return; // user closed the picker
      setState(() => _documentName = file.name);
    } catch (e) {
      _showMessage('Could not open your photos. Please try again.');
    }
  }

  // CREATE: save the registration as a pending request
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final address = _addressController.text.trim();

    try {
      await FirebaseFirestore.instance.collection(kRequestsCollection).add({
        'name': _nameController.text.trim(),
        'cuisine': _cuisineController.text.trim(),
        'owner': _ownerController.text.trim(),
        'address': address,
        'city': cityOf(address),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'tables': int.parse(_tablesController.text.trim()),
        'documentName': _documentName ?? '',
        'status': 'pending',
        'submittedBy': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await _showSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMessage('Could not send your request. Check your internet.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showSuccess() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.task_alt, color: kApproveGreen, size: 44),
        title: const Text('Request sent!'),
        content: Text(
          'Thank you. Our admin team will review '
          '"${_nameController.text.trim()}" and contact you at '
          '${_emailController.text.trim()}.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _contactSupport() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Contact support'),
        content: const Text(
          'Email: support@tableease.lk\nPhone: 074 379 8515\n\n'
          'We reply within one working day.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value, String message) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Back, logo and title
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.chevron_left, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const AdminBrandText(fontSize: 16),
                  Container(
                    width: 1,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: AppColors.border,
                  ),
                  const Text(
                    'Register Restaurant',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Restaurant Registration',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Join the TableEase network and manage bookings & '
                        'queues',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 22),

                      _field(
                        label: 'RESTAURANT NAME',
                        controller: _nameController,
                        hint: 'e.g. The Gallery Café',
                        validator: (v) =>
                            _required(v, 'Please enter the restaurant name'),
                      ),
                      _field(
                        label: 'CUISINE',
                        controller: _cuisineController,
                        hint: 'e.g. Sri Lankan, Seafood, Café',
                        validator: (v) =>
                            _required(v, 'Please enter the type of food'),
                      ),
                      _field(
                        label: 'OWNER NAME',
                        controller: _ownerController,
                        hint: 'e.g. Nuwan Fernando',
                        validator: (v) =>
                            _required(v, "Please enter the owner's name"),
                      ),
                      _field(
                        label: 'ADDRESS',
                        controller: _addressController,
                        hint: 'e.g. 240 Galle Road, Colombo 03',
                        validator: (v) =>
                            _required(v, 'Please enter the address'),
                      ),
                      _field(
                        label: 'PHONE NUMBER',
                        controller: _phoneController,
                        hint: '+94 77 123 4567',
                        keyboardType: TextInputType.phone,
                        capitalize: false,
                        validator: (v) {
                          final digits =
                              (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                          return digits.length < 9
                              ? 'Please enter a valid phone number'
                              : null;
                        },
                      ),
                      _field(
                        label: 'EMAIL',
                        controller: _emailController,
                        hint: 'gallerycafe@tableease.com',
                        keyboardType: TextInputType.emailAddress,
                        capitalize: false,
                        validator: (v) {
                          final email = (v ?? '').trim();
                          return (email.contains('@') && email.contains('.'))
                              ? null
                              : 'Please enter a valid email';
                        },
                      ),
                      _field(
                        label: 'NUMBER OF TABLES',
                        controller: _tablesController,
                        hint: '12',
                        keyboardType: TextInputType.number,
                        capitalize: false,
                        validator: (v) {
                          final tables = int.tryParse((v ?? '').trim());
                          if (tables == null || tables < 1 || tables > 100) {
                            return 'Enter a number from 1 to 100';
                          }
                          return null;
                        },
                      ),

                      // Verification document upload
                      const AdminSectionLabel('VERIFICATION DOCUMENTS'),
                      const SizedBox(height: 8),
                      _uploadBox(),
                      const SizedBox(height: 18),

                      // Terms
                      const Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                          children: [
                            TextSpan(text: 'By submitting, you agree to '),
                            TextSpan(
                              text: 'TableEase restaurant partner terms',
                              style: TextStyle(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Submit
                      ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Submit'),
                      ),
                      const SizedBox(height: 14),

                      // Already registered? Staff Login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already registered? ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const LoginScreen(role: 'staff'),
                                ),
                              );
                            },
                            child: const Text(
                              'Staff Login',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Need help? ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          GestureDetector(
                            onTap: _contactSupport,
                            child: const Text(
                              'Contact support',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // One labelled text field
  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool capitalize = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionLabel(label),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.next,
            textCapitalization:
                capitalize ? TextCapitalization.words : TextCapitalization.none,
            validator: validator,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }

  // Dashed box: "Upload business document"
  Widget _uploadBox() {
    final bool hasFile = _documentName != null;

    return Semantics(
      button: true,
      label: hasFile
          ? 'Document attached: $_documentName. Tap to change.'
          : 'Upload business document',
      child: GestureDetector(
        onTap: _pickDocument,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: hasFile ? kApproveGreen : AppColors.border,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            child: Column(
              children: [
                Icon(
                  hasFile ? Icons.task_alt : Icons.cloud_upload_outlined,
                  size: 30,
                  color: hasFile ? kApproveGreen : AppColors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  hasFile ? 'Document attached' : 'Upload business document',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasFile
                      ? '$_documentName  •  tap to change'
                      : 'BR Certificate, Food License (photo)',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Draws a dashed rounded border around the upload box
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(14),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
