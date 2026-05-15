import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/yoga_pose.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedDuration = 5;
  List<YogaPose> _displayedPoses = YogaPose.poses;
  String _selectedCategory = "All Poses";

  void _filterByCategory(YogaCategory category) {
    setState(() {
      _displayedPoses = category.poses;
      _selectedCategory = category.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF004D40),
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Yoga Trainer AI', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00695C), Color(0xFF004D40)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Set Session Time"),
                  const SizedBox(height: 12),
                  _buildDurationSelector(),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Yoga Categories"),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: YogaCategory.categories.length,
                      itemBuilder: (context, index) {
                        return _buildCategoryCard(YogaCategory.categories[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(_selectedCategory),
                      if (_selectedCategory != "All Poses")
                        TextButton(
                          onPressed: () => setState(() { _displayedPoses = YogaPose.poses; _selectedCategory = "All Poses"; }),
                          child: const Text("Show All", style: TextStyle(color: Color(0xFF004D40))),
                        )
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildPoseCard(_displayedPoses[index]),
                childCount: _displayedPoses.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF004D40)),
    );
  }

  Widget _buildDurationSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [5, 10, 15, 20].map((mins) {
        bool isSelected = _selectedDuration == mins;
        return GestureDetector(
          onTap: () => setState(() => _selectedDuration = mins),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF004D40) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF004D40).withOpacity(0.3)),
            ),
            child: Text("$mins min", style: GoogleFonts.outfit(color: isSelected ? Colors.white : const Color(0xFF004D40), fontWeight: FontWeight.w600)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryCard(YogaCategory category) {
    return GestureDetector(
      onTap: () => _filterByCategory(category),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(image: AssetImage(category.image), fit: BoxFit.cover),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Colors.black54, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
          ),
          padding: const EdgeInsets.all(12),
          child: Text(category.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPoseCard(YogaPose pose) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(pose.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
        ),
        title: Text(pose.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        subtitle: Text(pose.description, style: GoogleFonts.outfit(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CameraScreen(pose: pose, durationMins: _selectedDuration))),
      ),
    );
  }
}
