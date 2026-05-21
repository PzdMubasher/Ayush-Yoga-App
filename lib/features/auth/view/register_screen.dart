import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/auth_repository.dart';
import '../viewmodel/register_viewmodel.dart';
import '../../../screens/category_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late RegisterViewModel _viewModel;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _viewModel = RegisterViewModel(AuthRepository());
    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (!mounted) return;

    if (_isLoading != _viewModel.isLoading) {
      setState(() {
        _isLoading = _viewModel.isLoading;
      });
    }

    if (_viewModel.isSuccess) {
      final successMsg = 'Registration Successful! Welcome to Ayush Yoga.';
      _viewModel.clearState();
      _handleRegisterSuccess(successMsg);
    } else if (_viewModel.errorMessage != null) {
      final errorMsg = _viewModel.errorMessage!;
      _viewModel.clearState();
      _handleRegisterError(errorMsg);
    }
  }

  void _handleRegisterSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00FF88),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Navigate to Home screen, clearing the navigation stack
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CategoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  void _handleRegisterError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleRegister() {
    if (_passwordController.text != _confirmPasswordController.text) {
      _handleRegisterError("Passwords do not match");
      return;
    }

    _viewModel.register(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF051C15), Color(0xFF023220)],
          ),
        ),
        child: Stack(
          children: [
            // Meditative background watermark
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/images/meditation.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Back Button
            Positioned(
              top: 50,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Branding & Greeting
                      const Text(
                        'AYUSH YOGA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start your wellness journey',
                        style: TextStyle(
                          color: const Color(0xFF00FF88).withOpacity(0.8),
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Translucent Glassmorphic Form Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign Up',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF023220),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Full Name Field
                            Text(
                              'Full Name',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nameController,
                              style: GoogleFonts.outfit(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Your name',
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF004D40),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF004D40),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Email Field
                            Text(
                              'Email Address',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.outfit(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'example@gmail.com',
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF004D40),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF004D40),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Password Field
                            Text(
                              'Password',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.outfit(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF004D40),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF004D40),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF004D40),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Confirm Password Field
                            Text(
                              'Confirm Password',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: GoogleFonts.outfit(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(
                                  Icons.lock_clock_outlined,
                                  color: Color(0xFF004D40),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF004D40),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF004D40),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF023220),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        'Create Account',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Footer: Link to Login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Sign In',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00FF88),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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
}
