import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'atps_store.dart';

class GuestDashboard extends StatefulWidget {
  const GuestDashboard({super.key});

  @override
  State<GuestDashboard> createState() => _GuestDashboardState();
}

class _GuestDashboardState extends State<GuestDashboard> {
  final store = AtpsStore(); // Access Singleton
  Timer? _refreshTimer;
  StreamSubscription<Position>? _positionStream;
  LatLng? _guestLocation;
  
  // The junction that is currently active and nearby
  Map<String, dynamic>? _nearbyActiveJunction;
  
  // TTS State
  final FlutterTts flutterTts = FlutterTts();
  String? _lastSpokenJunctionId;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    _initTts();
    store.fetchSignals();
    store.fetchEmergencyRequests();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      store.fetchSignals(hideLoading: true);
      store.fetchEmergencyRequests(hideLoading: true);
      _checkProximity();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _positionStream?.cancel();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  void _triggerTtsAlert(String id) {
     if (_lastSpokenJunctionId != id) {
        _lastSpokenJunctionId = id;
        flutterTts.speak("Ambulance approaching from behind. Move to the left.");
     }
  }

  void _triggerTtsCleared() {
     if (_lastSpokenJunctionId != null) {
        flutterTts.speak("Emergency cleared. Resume normal driving.");
        _lastSpokenJunctionId = null;
     }
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _guestLocation = LatLng(position.latitude, position.longitude);
        });
        _checkProximity();
      }
    });

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
         _guestLocation = LatLng(pos.latitude, pos.longitude);
      });
      _checkProximity();
    }
  }

  void _checkProximity() {
    if (_guestLocation == null) return;
    
    final activeSignals = store.trafficSignals.value.where((s) => s['status'] == 'GREEN').toList();
    if (activeSignals.isEmpty) {
      if (_nearbyActiveJunction != null) {
        setState(() => _nearbyActiveJunction = null);
        _triggerTtsCleared();
      }
      return;
    }

    const Distance distance = Distance();
    Map<String, dynamic>? closest;
    double minDistance = double.infinity;

    for (var signal in activeSignals) {
      if (signal['lat'] == null || signal['lon'] == null) continue;
      
      final double lat = signal['lat'] is String ? double.tryParse(signal['lat']) ?? 0 : (signal['lat'] as num).toDouble();
      final double lon = signal['lon'] is String ? double.tryParse(signal['lon']) ?? 0 : (signal['lon'] as num).toDouble();
      
      if (lat == 0 || lon == 0) continue;

      final dist = distance.as(LengthUnit.Meter, _guestLocation!, LatLng(lat, lon));
      if (dist < minDistance) {
        minDistance = dist;
        closest = signal;
      }
    }

    // Trigger radius of 1000 meters for guest alert
    if (minDistance <= 1000 && closest != null) {
      if (_nearbyActiveJunction?.entries.toString() != closest.entries.toString()) {
        setState(() => _nearbyActiveJunction = closest);
        _triggerTtsAlert(closest['id']);
      }
    } else {
      if (_nearbyActiveJunction != null) {
        setState(() => _nearbyActiveJunction = null);
        _triggerTtsCleared();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // 1. ACTIVE ALERTS (Dynamic based on Proximity)
            Watch((context) {
              final activeReqs = store.emergencyRequests.value.where((req) => req['status'] == 'APPROVED').toList();
              if (_nearbyActiveJunction != null) {
                // If there's an active emergency and a nearby green junction, show the alert!
                final unitName = activeReqs.isNotEmpty ? activeReqs.last['unit'] : "An Ambulance";
                return _buildAlertBanner(unitName, _nearbyActiveJunction!['name']);
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
    // Default to Kochi center if no guest location or nearby active signal
    final centerPos = _guestLocation ?? const LatLng(9.9816, 76.2999);

    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _nearbyActiveJunction != null ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white10, width: 2),
        boxShadow: _nearbyActiveJunction != null ? [
           BoxShadow(color: Colors.redAccent.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 2)
        ] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: centerPos,
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
                if (_guestLocation != null)
                  _buildMapMarker(_guestLocation!, Colors.blueAccent, Icons.my_location),

                // Plot live traffic signals from backend
                ...store.trafficSignals.value.map((sig) {
                   final lat = sig['lat'] is String ? double.tryParse(sig['lat']) : (sig['lat'] as num?)?.toDouble();
                   final lon = sig['lon'] is String ? double.tryParse(sig['lon']) : (sig['lon'] as num?)?.toDouble();
                   if (lat == null || lon == null) return null;
                   
                   Color color = sig['status'] == 'GREEN' ? Colors.greenAccent : Colors.redAccent;
                   return _buildMapMarker(LatLng(lat, lon), color, Icons.traffic);
                }).whereType<Marker>(),
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