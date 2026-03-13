import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'atps_store.dart';

class GuestDashboard extends StatelessWidget {
  const GuestDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AtpsStore(); // Access Singleton

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E14),
        title: Text("Kochi Public Traffic Monitor", 
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        centerTitle: true,
        leading: const BackButton(color: Colors.white70),
        actions: [
          _buildLiveStatusBadge(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ACTIVE ALERTS (Dynamic)
            Watch((context) {
              final activeReqs = store.emergencyRequests.value.where((req) => req['status'] == 'APPROVED').toList();
              if (activeReqs.isNotEmpty) {
                final req = activeReqs.last;
                return _buildAlertBanner(req['unit'], req['location']);
              }
              return _buildNoActiveAlertsBanner();
            }),
            
            const SizedBox(height: 24),

            // 2. DUMMY LIVE MAP
            Text("Live Traffic Snapshot", 
              style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Watch((context) => _buildDummyMap(store)),
            
            const SizedBox(height: 24),

            // 3. TEXT-BASED DIRECTION DIALOG (Dynamic)
            Watch((context) {
              final activeReqs = store.emergencyRequests.value.where((req) => req['status'] == 'APPROVED').toList();
              if (activeReqs.isEmpty) return const SizedBox.shrink();
              
              final req = activeReqs.last;
              return Column(
                children: [
                   _buildDirectionDialog(req),
                   const SizedBox(height: 30),
                ]
              );
            }),

            // 4. RECENT ACTIVITY FEED
            Text("Recent Emergency Routes", 
              style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            Watch((context) {
              final completedReqs = store.emergencyRequests.value.where((req) => req['status'] == 'COMPLETED').toList();
              
              if (completedReqs.isEmpty) {
                 return const Padding(
                   padding: EdgeInsets.symmetric(vertical: 20),
                   child: Text("No recent emergencies.", style: TextStyle(color: Colors.grey)),
                 );
              }
              
              return Column(
                children: completedReqs.reversed.take(5).map((req) => 
                  _buildActivityItem(req['unit'], req['location'], "Recently", Colors.greenAccent)
                ).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- NEW: DIRECTION DIALOG BOX ---
  Widget _buildDirectionDialog(Map<String, dynamic> activeReq) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.redAccent.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: -5)
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle
                ),
                child: const Icon(LucideIcons.navigation, color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 15),
              Text("EMERGENCY TRACKER", 
                style: GoogleFonts.rajdhani(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "An emergency vehicle (${activeReq['unit']}) is currently active.",
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            "Path: ${activeReq['location']}",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
             children: [
                const Icon(LucideIcons.clock, color: Colors.grey, size: 16),
                const SizedBox(width: 6),
                Text(
                  "Estimated ETA: ${activeReq['eta'] ?? 'Unknown'}",
                  style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600),
                ),
             ]
          )
        ],
      ),
    );
  }

  // --- MAP WIDGETS ---
  Widget _buildDummyMap(AtpsStore store) {
    final activeReqs = store.emergencyRequests.value.where((req) => req['status'] == 'APPROVED').toList();
    final hasActive = activeReqs.isNotEmpty;

    // Kochi Coordinates
    final kochiCenter = const LatLng(9.9816, 76.2999);
    final medicalTrust = const LatLng(9.9658, 76.2947);
    final vyttilaJn = const LatLng(9.9674, 76.3197);
    final mgRoad = const LatLng(9.9745, 76.2801);

    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hasActive ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white10, width: 2),
        boxShadow: hasActive ? [
           BoxShadow(color: Colors.redAccent.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 2)
        ] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: kochiCenter,
            initialZoom: 13.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate, 
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', 
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(
              markers: [
                _buildMapMarker(medicalTrust, Colors.blueAccent, Icons.local_hospital),
                _buildMapMarker(vyttilaJn, Colors.greenAccent, Icons.traffic),
                _buildMapMarker(mgRoad, hasActive ? Colors.greenAccent : Colors.redAccent, Icons.traffic),
                
                if (hasActive)
                  Marker(
                    point: const LatLng(9.9700, 76.3050), // Simulated moving point
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.redAccent.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 8)
                            ]
                          ),
                          child: const Icon(Icons.emergency, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6)
                          ),
                          child: Text(activeReqs.last['unit'], style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))
                        )
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER COMPONENTS ---
  Marker _buildMapMarker(LatLng point, Color color, IconData icon) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Container(
         padding: const EdgeInsets.all(4),
         decoration: BoxDecoration(
            color: const Color(0xFF151B25),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.5))
         ),
         child: Icon(icon, color: color, size: 20)
      ),
    );
  }

  Widget _buildAlertBanner(String unit, String path) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4))
      ),
      child: Row(
        children: [
          Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle
             ),
             child: const Icon(LucideIcons.siren, color: Colors.redAccent, size: 24)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("EMERGENCY OVERRIDE ACTIVE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text("$unit is heading via $path. Please clear the way if you are in the area.", style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveAlertsBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.2))
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.checkCircle, color: Colors.greenAccent, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Normal Traffic Conditions", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("No active emergency vehicles in your vicinity.", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String desc, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151B25), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
           BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.local_shipping, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.w600)),
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