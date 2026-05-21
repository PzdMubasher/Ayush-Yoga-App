import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import 'category_screen.dart';
import '../features/auth/model/auth_repository.dart';
import '../features/auth/view/login_screen.dart';

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

  // Typewriter animation variables
  String _fullQuote = "";
  String _displayedQuote = "";
  int _charIndex = 0;
  Timer? _typewriterTimer;

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

    _startTypewriter("Yoga is the journey to the self.");
    _checkLanguageStatus();
  }

  void _startTypewriter(String quote) {
    _typewriterTimer?.cancel();
    setState(() {
      _fullQuote = quote;
      _displayedQuote = "";
      _charIndex = 0;
    });
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (_charIndex < _fullQuote.length) {
        setState(() {
          _displayedQuote += _fullQuote[_charIndex];
          _charIndex++;
        });
      } else {
        _typewriterTimer?.cancel();
      }
    });
  }

  Future<void> _checkLanguageStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLanguageSet = prefs.getBool('is_language_set') ?? false;

    // Minimum splash duration (increased to 4 seconds)
    await Future.delayed(const Duration(milliseconds: 4000));
    if (!mounted) return;

    if (isLanguageSet) {
      _navigateToHome();
    } else {
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      setState(() {
        _showLanguageSelection = true;
        _selectedLang = langProvider.currentLanguage;
      });
      _startTypewriter(_selectedLang == 'hi' 
          ? "योग स्वयं की यात्रा है।" 
          : _selectedLang == 'te'
              ? "యోగా స్వయం యొక్క ప్రయాణం."
              : "Yoga is the journey to the self.");
    }
  }

  Future<void> _navigateToHome() async {
    if (!mounted) return;
    
    final isLoggedIn = await AuthRepository().isLoggedIn();
    if (!mounted) return;

    final Widget nextScreen = isLoggedIn ? const CategoryScreen() : const LoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  Widget _buildTopLogoCard(String assetPath) {
    return Container(
      width: 95,
      height: 95,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildLanguageOption(String code, String name) {
    bool isSelected = _selectedLang == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLang = code;
        });
        String quote = "Yoga is the journey to the self.";
        if (code == 'hi') quote = "योग स्वयं की यात्रा है।";
        if (code == 'te') quote = "యోగా స్వయం యొక్క ప్రయాణం.";
        _startTypewriter(quote);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF023220) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF00FF88) : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF00FF88).withOpacity(0.2), blurRadius: 8)] : [],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
        child: Stack(
          children: [
            // Background Image Overlay (Serene Meditation image watermark)
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/images/meditation.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Content
            FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    
                    // Top: Logos Side-by-Side inside elegant white rounded cards (Reference Style)
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTopLogoCard('assets/images/Ayush_yoga.jpeg'),
                          const SizedBox(width: 20),
                          _buildTopLogoCard('assets/images/image1.png'),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Center: App Branding
                    const Text(
                      'AYUSH YOGA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedLang == 'hi' ? 'आत्मा और शरीर का मिलन' : 'Harmonize Your Soul',
                      style: TextStyle(
                        color: const Color(0xFF00FF88).withOpacity(0.8),
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 2,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Animated Typewriter Quote
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        height: 50, // Fixed height to prevent UI bouncing
                        child: Text(
                          _displayedQuote,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Bottom Card (Translucent White Container matching reference layout) - ALWAYS VISIBLE
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ministry of Ayush Banner inside the bottom card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Image.asset(
                                'assets/images/ministry.png', 
                                height: 48, 
                                fit: BoxFit.contain
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            if (_showLanguageSelection) ...[
                              // Language instruction
                              Text(
                                _selectedLang == 'hi'
                                    ? 'भाषा चुनें / Select Language'
                                    : _selectedLang == 'te'
                                        ? 'భాష ఎంచుకోండి / Select Language'
                                        : 'Select Language / भाषा चुनें',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Buttons English / हिन्दी / తెలుగు
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _buildLanguageOption('en', 'English'),
                                  _buildLanguageOption('hi', 'हिन्दी'),
                                  _buildLanguageOption('te', 'తెలుగు'),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // Continue Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
                                    await langProvider.setLanguage(_selectedLang);
                                    _navigateToHome();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00FF88),
                                    foregroundColor: const Color(0xFF051C15),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    elevation: 4,
                                    shadowColor: const Color(0xFF00FF88).withOpacity(0.4),
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
                              ),
                            ] else ...[
                              const SizedBox(height: 10),
                              const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF023220)),
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
