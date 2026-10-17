import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../customer/customer_main_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  // The role picked on the "Who are you?" screen
  final String role;

  const CreateAccountScreen({super.key, required this.role});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _agreed = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Could not create account. Please try again.';
    }
  }

  // Creates the account and saves the profile
  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreed) {
      _showMessage('Please agree to the terms to continue.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create the login account in Firebase Authentication
      final result = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 2. CREATE: save the user's profile in the "users" collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': widget.role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Account created successfully');
      if (!mounted) return;

      if (widget.role == 'customer') {
        // Firebase logs the user in automatically, so skip the Login step
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const CustomerMainScreen()),
              (route) => false,
        );
      } else {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_errorText(e.code));
    } catch (e) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
                      // Logo and app name
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Image.asset(
                                  'assets/images/logo_icon.png',
                                  errorBuilder: (context, error, stack) =>
                                  const Icon(
                                    Icons.table_restaurant,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title and subtitle
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Join TableEase to book tables and track live queues',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Full name
                      _label('FULL NAME'),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Email
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
                      const SizedBox(height: 14),

                      // Phone number
                      _label('PHONE NUMBER'),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(),
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

                      // Password
                      _label('PASSWORD (MIN. 8 CHARACTERS)'),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          suffixIcon: _showHideButton(_hidePassword, () {
                            setState(() => _hidePassword = !_hidePassword);
                          }),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Confirm password
                      _label('CONFIRM PASSWORD'),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _hideConfirm,
                        decoration: InputDecoration(
                          suffixIcon: _showHideButton(_hideConfirm, () {
                            setState(() => _hideConfirm = !_hideConfirm);
                          }),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Terms checkbox (the text can be tapped too)
                      GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreed,
                                activeColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.border,
                                  width: 1.5,
                                ),
                                onChanged: (value) {
                                  setState(() => _agreed = value ?? false);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                ),
                                children: [
                                  TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'terms',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Create Account button (spinner while loading)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createAccount,
                        child: _isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                            : const Text('Create Account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom part: back to Login
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
                    'Already have an account? ',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Login',
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

  // "Show" / "Hide" button inside password fields
  Widget _showHideButton(bool hidden, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        hidden ? 'Show' : 'Hide',
        style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
      ),
    );
  }
}