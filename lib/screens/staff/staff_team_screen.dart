import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Team screen (managers only): add or remove staff by email.
// Each person is a document in staff_members/{email}.
// Staff then sign up with the same email and log in to this restaurant.
class StaffTeamScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const StaffTeamScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<StaffTeamScreen> createState() => _StaffTeamScreenState();
}

class _StaffTeamScreenState extends State<StaffTeamScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _teamStream;

  CollectionReference<Map<String, dynamic>> get _members =>
      FirebaseFirestore.instance.collection('staff_members');

  String get _myEmail =>
      (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    // READ (live): everyone who works at this restaurant
    _teamStream = _members
        .where('restaurantId', isEqualTo: widget.restaurantId)
        .snapshots();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // CREATE: opens the "Add staff" form
  Future<void> _openAddDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => _AddStaffDialog(
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
      ),
    );
    if (added == true) {
      _showMessage(
        'Staff added. They can sign up and log in with that email.',
      );
    }
  }

  // DELETE: removes a staff member (asks first)
  Future<void> _remove(String email, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name?'),
        content: Text(
          '$name will no longer be able to manage ${widget.restaurantName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _members.doc(email).delete();
      _showMessage('$name removed from the team.');
    } catch (e) {
      _showMessage('Could not remove. Check your internet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Team'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add staff'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _teamStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Could not load your team. Check your internet.',
                style: TextStyle(color: AppColors.textGrey),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Managers first, then staff by name
          final people = snapshot.data!.docs.map((d) => d.data()).toList()
            ..sort((a, b) {
              final aManager = a['role'] == 'manager' ? 0 : 1;
              final bManager = b['role'] == 'manager' ? 0 : 1;
              if (aManager != bManager) return aManager - bManager;
              return (a['name'] ?? '')
                  .toString()
                  .compareTo((b['name'] ?? '').toString());
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              Text(
                widget.restaurantName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add your staff by email. They sign up with the same email '
                    'and log in straight to this restaurant.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              for (final person in people)
                _memberCard(
                  email: (person['email'] ?? '').toString(),
                  name: (person['name'] ?? '').toString(),
                  isManager: person['role'] == 'manager',
                ),
              if (people.length <= 1)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'No staff yet. Tap "Add staff" to add your first team member.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // One person in the team list
  Widget _memberCard({
    required String email,
    required String name,
    required bool isManager,
  }) {
    final bool isMe = email == _myEmail;
    final String shownName = name.isEmpty ? email : name;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              _initials(shownName),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '$shownName (You)' : shownName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isManager ? AppColors.primaryLight : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isManager ? 'Manager' : 'Staff',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isManager ? AppColors.primary : AppColors.textGrey,
              ),
            ),
          ),
          // Managers can remove staff, but not other managers
          if (!isManager)
            IconButton(
              tooltip: 'Remove $shownName',
              icon: const Icon(
                Icons.person_remove_outlined,
                color: Color(0xFFDC2626),
              ),
              onPressed: () => _remove(email, shownName),
            ),
        ],
      ),
    );
  }

  String _initials(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

// Popup form: name + email of the new staff member
class _AddStaffDialog extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const _AddStaffDialog({
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // CREATE: staff_members/{email}
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final email = _emailController.text.trim().toLowerCase();

    try {
      await FirebaseFirestore.instance
          .collection('staff_members')
          .doc(email)
          .set({
        'email': email,
        'name': _nameController.text.trim(),
        'restaurantId': widget.restaurantId,
        'restaurantName': widget.restaurantName,
        'role': 'staff',
        'addedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      setState(() {
        _saving = false;
        // The rules block adding an email that already works somewhere
        _error = e.code == 'permission-denied'
            ? 'This email is already added to a restaurant.'
            : 'Could not add staff. Check your internet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add staff'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please enter a name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an email';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text('Add'),
        ),
      ],
    );
  }
}