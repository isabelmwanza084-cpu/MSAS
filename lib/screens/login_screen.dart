import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'clinic_admin_dashboard.dart';
import 'clinic_staff_dashboard.dart';
import 'district_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Design colours
  static const Color _teal = Color(0xFF3A8878);
  static const Color _gradientTop = Color(0xFF33736A);
  static const Color _gradientBottom = Color(0xFF6BBDEE);
  static const Color _titleColor = Color(0xFF16303A);
  static const Color _mutedText = Color(0xFF5F7480);
  static const Color _fieldFill = Color(0xFFF6F8FA);
  static const Color _fieldBorder = Color(0xFFD5DEE3);

  final AuthService _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      showMessage('Please enter email and password.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = await _authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user == null) {
        showMessage('Login failed.');
        return;
      }

      final userData = await _authService.getUserData(user.uid);

      if (userData == null) {
        showMessage('User information was not found.');
        return;
      }

      final role = userData['role'];

      if (!mounted) return;

      if (role == 'clinicAdministrator') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ClinicAdminDashboard(),
          ),
        );
      } else if (role == 'clinicStaff') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ClinicStaffDashboard(),
          ),
        );
      } else if (role == 'districtSupplyOfficer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DistrictDashboard(),
          ),
        );
      } else {
        showMessage('Invalid user role.');
      }
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      showMessage('ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _mutedText, fontSize: 16),
      prefixIcon: Icon(icon, color: _mutedText, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 20),
      enabledBorder: border(_fieldBorder, 1.5),
      focusedBorder: border(_teal, 2),
      border: border(_fieldBorder, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double badgeSize = 104;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            colors: [_gradientTop, _teal, _gradientBottom],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // White card
                  Container(
                    margin: const EdgeInsets.only(top: badgeSize / 2),
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      badgeSize / 2 + 28,
                      24,
                      28,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Medicine Stock System',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Log in to continue',
                          style: TextStyle(
                            fontSize: 17,
                            color: _mutedText,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Email
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            fontSize: 17,
                            color: _titleColor,
                          ),
                          decoration: _fieldDecoration(
                            hint: 'Email',
                            icon: Icons.mail_outline,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Password
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          style: TextStyle(
                            fontSize: 17,
                            color: _titleColor,
                          ),
                          decoration: _fieldDecoration(
                            hint: 'Password',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _mutedText,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Login button
                        Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: _teal.withValues(alpha: 38),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : loginUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _teal,
                              disabledBackgroundColor: _teal.withValues(alpha: 38),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 22),

                      ],
                    ),
                  ),

                  // Floating circular badge
                  Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 38),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      size: 52,
                      color: _teal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
