import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../start/splash_screen.dart';

// The Profile tab: view, edit or delete your account
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // "Kasun Perera" becomes "KP"
  String _initials(String name, String email) {
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).take(2);
    if (words.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    return words.map((w) => w[0].toUpperCase()).join();
  }

  String _dateText(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  // Opens the start screen and clears every other screen
  void _goToStart(NavigatorState navigator) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    return SafeArea(
      // READ (live): this user's profile from the "users" collection
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load your profile.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final name = (data['fullName'] ?? '').toString();
          final email = (data['email'] ?? user?.email ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final role = (data['role'] ?? 'customer').toString();
          final created = data['createdAt'] as Timestamp?;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),

              // Avatar, name and role
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _initials(name, email),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name.isEmpty ? 'No name yet' : name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role.isEmpty
                            ? 'Customer'
                            : role[0].toUpperCase() + role.substring(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Details
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _row(Icons.email_outlined, 'Email', email),
                    const Divider(height: 1, color: AppColors.border),
                    _row(
                      Icons.phone_outlined,
                      'Phone',
                      phone.isEmpty ? 'Not added' : phone,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _row(
                      Icons.calendar_today_outlined,
                      'Member since',
                      created == null ? '-' : _dateText(created.toDate()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Edit profile
              ElevatedButton.icon(
                onPressed: () => _editProfile(context, name, phone),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit profile'),
              ),
              const SizedBox(height: 10),

              // Log out
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Danger zone
              const Text(
                'DANGER ZONE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _deleteAccount(context),
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('Delete account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This removes your profile and saved cards. It cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          );
        },
      ),
    );
  }

  // One row in the details box
  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textGrey),
          const SizedBox(width: 12),
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
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

  // UPDATE: opens the edit sheet
  Future<void> _editProfile(
      BuildContext context,
      String name,
      String phone,
      ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EditProfileSheet(name: name, phone: phone),
    );
    if (saved == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  // Signs out and goes back to the start
  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log in again at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    _goToStart(navigator);
  }

  // DELETE: removes the profile, saved cards and the login account
  Future<void> _deleteAccount(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Ask for the password to confirm
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (password == null || password.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      // Firebase needs a fresh login before an account can be deleted
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      // DELETE: saved cards first (Firestore does not remove them by itself)
      final cards = await userDoc.collection('cards').get();
      for (final card in cards.docs) {
        await card.reference.delete();
      }

      // DELETE: the profile document
      await userDoc.delete();

      // DELETE: the login account
      await user.delete();

      _goToStart(navigator);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account was deleted')),
      );
    } on FirebaseAuthException catch (e) {
      final wrongPassword =
          e.code == 'wrong-password' || e.code == 'invalid-credential';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            wrongPassword
                ? 'Password is incorrect.'
                : 'Could not delete the account. Please try again.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('DELETE ACCOUNT ERROR: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not delete the account. Please try again.'),
        ),
      );
    }
  }
}

// Bottom sheet to change the name and phone number
class _EditProfileSheet extends StatefulWidget {
  final String name;
  final String phone;

  const _EditProfileSheet({required this.name, required this.phone});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.name);
  late final _phoneController = TextEditingController(text: widget.phone);
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // UPDATE: save the new name and phone number
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('PROFILE UPDATE ERROR: $e');
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Moves the sheet up when the keyboard opens
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Form(
            key: _formKey,
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
                const SizedBox(height: 16),
                const Text(
                  'Edit profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 18),

                _label('FULL NAME'),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Kasun Perera',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _label('PHONE NUMBER'),
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

                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Color(0xFF555555),
        ),
      ),
    );
  }
}

// Popup that asks for the password before deleting the account
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your profile and saved cards will be removed. '
                'Enter your password to confirm.',
            style: TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Password'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _passwordController.text),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}