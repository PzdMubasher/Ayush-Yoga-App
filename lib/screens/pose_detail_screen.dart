import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/yoga_pose.dart';
import 'camera_screen.dart';

class PoseDetailScreen extends StatefulWidget {
  final YogaPose pose;
  const PoseDetailScreen({super.key, required this.pose});

  @override
  State<PoseDetailScreen> createState() => _PoseDetailScreenState();
}

class _PoseDetailScreenState extends State<PoseDetailScreen> {
  int _selectedDuration = 5;
  String _selectedLevel = "Beginner";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF004D40),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(widget.pose.imageUrl, fit: BoxFit.cover),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black54, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildBenefitsSection(),
                  const SizedBox(height: 32),
                  _buildSessionSetupCard(),
                  const SizedBox(height: 40),
                  _buildStartButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.pose.name, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF004D40))),
        const SizedBox(height: 8),
        Text(widget.pose.description, style: GoogleFonts.outfit(fontSize: 16, color: Colors.black54)),
      ],
    );
  }

  Widget _buildBenefitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Key Benefits", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.pose.benefits.map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 14, color: Colors.teal),
                const SizedBox(width: 6),
                Text(b, style: GoogleFonts.outfit(fontSize: 13, color: Colors.teal, fontWeight: FontWeight.w600)),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildSessionSetupCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Setup Your Session", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildOptionLabel("Intensity Level"),
          const SizedBox(height: 12),
          _buildLevelSelector(),
          const SizedBox(height: 24),
          _buildOptionLabel("Session Duration"),
          const SizedBox(height: 12),
          _buildDurationSelector(),
        ],
      ),
    );
  }

  Widget _buildOptionLabel(String label) {
    return Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.black45, fontWeight: FontWeight.w600));
  }

  Widget _buildLevelSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ["Beginner", "Intermediate", "Advanced"].map((lvl) {
        bool isSelected = _selectedLevel == lvl;
        return GestureDetector(
          onTap: () => setState(() => _selectedLevel = lvl),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: isSelected ? Colors.orange : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: Text(lvl, style: GoogleFonts.outfit(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [5, 10, 15, 20].map((mins) {
        bool isSelected = _selectedDuration == mins;
        return GestureDetector(
          onTap: () => setState(() => _selectedDuration = mins),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: isSelected ? const Color(0xFF004D40) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: Text("$mins min", style: GoogleFonts.outfit(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CameraScreen(pose: widget.pose, durationMins: _selectedDuration, level: _selectedLevel))),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF004D40),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: const Color(0xFF004D40).withOpacity(0.4),
        ),
        child: Text("Start AI Practice", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
