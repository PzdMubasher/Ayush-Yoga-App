import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/auth_repository.dart';
import '../viewmodel/login_viewmodel.dart';
import 'register_screen.dart';
import '../../../screens/category_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late LoginViewModel _viewModel;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _viewModel = LoginViewModel(AuthRepository());
    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      final successMsg = 'Welcome back to Ayush Yoga!';
      _viewModel.clearState();
      _handleLoginSuccess(successMsg);
    } else if (_viewModel.errorMessage != null) {
      final errorMsg = _viewModel.errorMessage!;
      _viewModel.clearState();
      _handleLoginError(errorMsg);
    }
  }

  void _handleLoginSuccess(String message) {
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

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CategoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _handleLoginError(String message) {
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

  void _handleLogin() {
    _viewModel.login(_emailController.text, _passwordController.text);
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
            // Meditative background watermark for visual luxury
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/images/meditation.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                        'Align Your Soul & Body',
                        style: TextStyle(
                          color: const Color(0xFF00FF88).withOpacity(0.8),
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 36),

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
                              'Sign In',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF023220),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Email Field
                            Text(
                              'Email Address',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                  vertical: 16,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Password Field
                            Text(
                              'Password',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                  vertical: 16,
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
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
                                        'Sign In',
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

                      const SizedBox(height: 28),

                      // Footer: Link to Sign Up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  transitionDuration: const Duration(
                                    milliseconds: 500,
                                  ),
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const RegisterScreen(),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(1, 0),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeInOut,
                                                ),
                                              ),
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
                            child: Text(
                              'Sign Up',
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
