import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../customer/customer_main_screen.dart';
import 'create_account_screen.dart';
import '../staff/staff_main_screen.dart';
import '../admin/admin_main_screen.dart';
import '../admin/restaurant_registration_screen.dart';

class LoginScreen extends StatefulWidget {
  // The role picked on the "Who are you?" screen
  final String role;

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _isLoading = false;

  // Turns the role code into a readable name
  String get _roleName {
    switch (widget.role) {
      case 'staff':
        return 'Restaurant Staff';
      case 'admin':
        return 'Admin';
      default:
        return 'Customer';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Shows a short message at the bottom of the screen
  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Turns Firebase error codes into simple messages
  String _errorText(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  // Staff only: finds the restaurant this staff member was added to.
  // The manager adds staff in staff_members/{email}.
  // Returns an error message, or null when everything is fine.
  Future<String?> _linkStaffRestaurant(User user) async {
    final db = FirebaseFirestore.instance;
    final email = (user.email ?? _emailController.text).trim().toLowerCase();

    // READ: my staff membership
    final member = await db.collection('staff_members').doc(email).get();
    if (!member.exists) {
      return "You haven't been added to a restaurant yet. "
          'Ask your manager to add your email.';
    }

    final data = member.data()!;
    final restaurantId = (data['restaurantId'] ?? '').toString();

    // READ: make sure the restaurant still exists
    final restaurant = await db.collection('restaurants').doc(restaurantId).get();
    if (!restaurant.exists) {
      return 'Your restaurant is no longer on TableEase. Please contact the admin.';
    }

    // WRITE: save the restaurant and staff role on my profile
    await db.collection('users').doc(user.uid).set({
      'restaurantId': restaurantId,
      'staffRole': (data['role'] ?? 'staff').toString(),
    }, SetOptions(merge: true));

    return null;
  }

  // Logs the user in with Firebase
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // READ: get this user's profile to check their role
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .get();

      if (doc.exists && doc.data()!['role'] != widget.role) {
        await FirebaseAuth.instance.signOut();
        _showMessage('This account is not registered as $_roleName.');
        return;
      }

      // Staff: open only the restaurant the manager added them to
      if (widget.role == 'staff') {
        String? staffError;
        try {
          staffError = await _linkStaffRestaurant(result.user!);
        } catch (e) {
          staffError = 'Could not load your restaurant. Check your internet.';
        }
        if (staffError != null) {
          await FirebaseAuth.instance.signOut();
          _showMessage(staffError);
          return;
        }
      }

      if (!mounted) return;

      if (widget.role == 'customer') {
        // Open the customer app and clear the login screens
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const CustomerMainScreen()),
              (route) => false,
        );
      } else if (widget.role == 'staff') {
        // Open the staff app and clear the login screens
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const StaffMainScreen()),
              (route) => false,
        );
      } else {
        // Open the admin app and clear the login screens
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AdminMainScreen()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_errorText(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Sends a password reset email
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter your email first, then tap Forgot password.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Password reset link sent to $email');
    } on FirebaseAuthException catch (e) {
      _showMessage(_errorText(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable part, so the keyboard does not hide the fields
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Logo, app name and role badge
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Image.asset(
                                  'assets/images/logo_icon.png',
                                  errorBuilder: (context, error, stack) =>
                                  const Icon(
                                    Icons.table_restaurant,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
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
                            const SizedBox(height: 10),

                            // "Logging in as: Customer" badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(fontSize: 12),
                                  children: [
                                    const TextSpan(
                                      text: 'Logging in as: ',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _roleName,
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title and subtitle
                      const Text(
                        'Login to your account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your details to manage reservations & queues',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Email field (empty box, label above)
                      _label('EMAIL'),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password field with Show / Hide (empty box, label above)
                      _label('PASSWORD'),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          suffixIcon: TextButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            child: Text(
                              _hidePassword ? 'Show' : 'Hide',
                              style: const TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),

                      // Forgot password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Login button (shows a spinner while loading)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                            : const Text('Login'),
                      ),

                      // Staff only: link to register a new restaurant
                      if (widget.role == 'staff') ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const RestaurantRegistrationScreen(),
                              ),
                            ),
                            child: const Text(
                              'New restaurant? Register here',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom part: link to Create Account
            // (admins are created in the Firebase console, so no sign up)
            if (widget.role != 'admin') ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateAccountScreen(role: widget.role),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Small grey label above each field
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