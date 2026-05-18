import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/yoga_pose.dart';
import '../providers/language_provider.dart';
import 'pose_detail_screen.dart';

class PoseListScreen extends StatelessWidget {
  final YogaCategory category;
  const PoseListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        title: Text(
          langProvider.translateDynamic(category.name),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF004D40),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: category.poses.length,
        itemBuilder: (context, index) {
          final pose = category.poses[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(pose.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
              ),
              title: Text(
                langProvider.translateDynamic(pose.name),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                langProvider.translateDynamic(pose.description),
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF004D40)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PoseDetailScreen(pose: pose)),
              ),
            ),
          );
        },
      ),
    );
  }
}
