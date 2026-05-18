import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import 'category_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _showLanguageSelection = false;
  String _selectedLang = 'en';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();

    _checkLanguageStatus();
  }

  Future<void> _checkLanguageStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLanguageSet = prefs.getBool('is_language_set') ?? false;

    // Minimum splash duration
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    if (isLanguageSet) {
      _navigateToHome();
    } else {
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      setState(() {
        _showLanguageSelection = true;
        _selectedLang = langProvider.currentLanguage;
      });
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000),
          pageBuilder: (context, animation, secondaryAnimation) => const CategoryScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildLanguageOption(String code, String name) {
    bool isSelected = _selectedLang == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLang = code;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00FF88) : Colors.white24,
            width: 2,
          ),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF00FF88).withOpacity(0.3), blurRadius: 10)] : [],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 150,
                  height: 150,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF88).withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'AYUSH YOGA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedLang == 'hi' ? 'आत्मा और शरीर का मिलन' : 'Harmonize Your Soul',
                style: TextStyle(
                  color: const Color(0xFF00FF88).withOpacity(0.8),
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2,
                ),
              ),
              if (_showLanguageSelection) ...[
                const SizedBox(height: 50),
                AnimatedOpacity(
                  opacity: _showLanguageSelection ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Column(
                    children: [
                      Text(
                        _selectedLang == 'hi' ? 'भाषा चुनें / Select Language' : 'Select Language / भाषा चुनें',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLanguageOption('en', 'English'),
                          const SizedBox(width: 16),
                          _buildLanguageOption('hi', 'हिन्दी'),
                        ],
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () async {
                          final langProvider = Provider.of<LanguageProvider>(context, listen: false);
                          await langProvider.setLanguage(_selectedLang);
                          _navigateToHome();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          foregroundColor: const Color(0xFF051C15),
                          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF00FF88).withOpacity(0.5),
                        ),
                        child: Text(
                          _selectedLang == 'hi' ? 'आगे बढ़ें' : 'Continue',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 100),
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
                    strokeWidth: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
