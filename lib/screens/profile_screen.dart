import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../features/auth/model/auth_repository.dart';
import '../features/auth/model/user_model.dart';
import '../features/auth/view/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadActiveUser();
  }

  Future<void> _loadActiveUser() async {
    final user = await AuthRepository().getActiveUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoadingUser = false;
      });
    }
  }

  void _showLogoutConfirmation(BuildContext context, LanguageProvider langProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              Text(
                langProvider.t('logout_confirm'),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF004D40),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            langProvider.t('logout_confirm_desc'),
            style: GoogleFonts.outfit(
              color: Colors.grey.shade700,
              fontSize: 16,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                langProvider.t('cancel'),
                style: GoogleFonts.outfit(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                navigator.pop(); // dismiss dialog
                await AuthRepository().logout();
                
                // Clear all navigation stack and push login screen
                navigator.pushAndRemoveUntil(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 600),
                    pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                langProvider.t('yes'),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogoutTile(BuildContext context, LanguageProvider langProvider) {
    return GestureDetector(
      onTap: () => _showLogoutConfirmation(context, langProvider),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.logout, color: Colors.red.shade800, size: 24),
                const SizedBox(width: 12),
                Text(
                  langProvider.t('logout'),
                  style: GoogleFonts.outfit(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.red.shade300, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004D40)),
        title: Consumer<LanguageProvider>(
          builder: (context, langProvider, child) {
            return Text(
              langProvider.t('profile_settings'),
              style: GoogleFonts.outfit(
                color: const Color(0xFF004D40),
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        centerTitle: true,
      ),
      body: Consumer<LanguageProvider>(
        builder: (context, langProvider, child) {
          if (_isLoadingUser) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004D40)),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Profile Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF004D40), Color(0xFF00695C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF004D40).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Color(0xFF004D40), size: 42),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser?.name ?? langProvider.t('yogi_name'),
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_currentUser != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _currentUser!.email,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer, color: Colors.white, size: 16),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${langProvider.t('total_minutes')}: 120 min',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Language Settings Section
                Text(
                  langProvider.t('change_language'),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLanguageTile(context, langProvider, 'en', 'English'),
                const SizedBox(height: 16),
                _buildLanguageTile(context, langProvider, 'hi', 'हिन्दी'),
                const SizedBox(height: 16),
                _buildLanguageTile(context, langProvider, 'te', 'తెలుగు'),
                const SizedBox(height: 32),
                _buildLogoutTile(context, langProvider),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, LanguageProvider langProvider, String code, String name) {
    bool isSelected = langProvider.currentLanguage == code;
    return GestureDetector(
      onTap: () {
        langProvider.setLanguage(code);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF004D40) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF004D40) : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected 
            ? [BoxShadow(color: const Color(0xFF004D40).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))] 
            : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 18,
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }
}
