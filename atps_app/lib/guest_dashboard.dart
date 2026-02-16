import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class GuestDashboard extends StatelessWidget {
  const GuestDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E14),
        title: Text("Kochi Public Traffic Monitor", 
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        leading: const BackButton(color: Colors.grey),
        actions: [
          _buildLiveStatusBadge(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ACTIVE ALERTS
            _buildAlertBanner(),
            const SizedBox(height: 24),

            // 2. DUMMY LIVE MAP
            const Text("Live Traffic Snapshot", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDummyMap(),
            
            const SizedBox(height: 24),

            // 3. TEXT-BASED DIRECTION DIALOG (NEW)
            _buildDirectionDialog(),

            const SizedBox(height: 30),

            // 4. RECENT ACTIVITY FEED
            const Text("Recent Emergency Routes", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildActivityItem("Ambulance 042", "Vyttila Hub → Medical Trust", "2 min ago", Colors.redAccent),
            _buildActivityItem("Fire Unit 09", "Marine Drive → Broadway Market", "15 min ago", Colors.orange),
          ],
        ),
      ),
    );
  }

  // --- NEW: DIRECTION DIALOG BOX ---
  Widget _buildDirectionDialog() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.redAccent.withValues(alpha: 0.05), blurRadius: 20)
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.navigation, color: Colors.redAccent, size: 22),
              const SizedBox(width: 15),
              Text("AMBULANCE TRACKER", 
                style: GoogleFonts.rajdhani(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "The active emergency vehicle is currently approaching from the SOUTH-EAST (Vyttila Hub area) moving towards NORTH (MG Road).",
            style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            "Estimated arrival at MG Road Junction: 4 minutes.",
            style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // --- MAP WIDGETS ---
  Widget _buildDummyMap() {
    return Container(
      height: 290,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        image: const DecorationImage(
          image: NetworkImage("https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Dark_map.png/640px-Dark_map.png"),
          fit: BoxFit.cover,
          opacity: 0.2
        )
      ),
      child: Stack(
        children: [
          _buildMapPin(top: 80, left: 60, color: Colors.blue, icon: Icons.local_hospital), // Medical Trust
          _buildMapPin(top: 150, right: 80, color: Colors.green, icon: Icons.traffic), // Vyttila Jn
          _buildMapPin(bottom: 100, left: 120, color: Colors.red, icon: Icons.traffic), // MG Road
          
          // Active Ambulance Pin
          Positioned(
            top: 120, left: 180,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)]
                  ),
                  child: const Icon(Icons.local_hospital, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 4),
                const Text("AMB-042", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER COMPONENTS ---
  Widget _buildMapPin({double? top, double? bottom, double? left, double? right, required Color color, required IconData icon}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF007BFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF007BFF).withValues(alpha: 0.3))
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.info, color: Color(0xFF007BFF)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Emergency Override Active", style: TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Ambulance heading from Vyttila to Medical Trust Hospital.", style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String desc, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B25), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05))
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.emergency, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildLiveStatusBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3))
      ),
      child: const Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colors.green),
          SizedBox(width: 6),
          Text("LIVE", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }
}