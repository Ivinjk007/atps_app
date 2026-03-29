import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'guest_dashboard.dart';
import 'driver_dashboard.dart';
import 'admin_dashboard.dart';
import 'atps_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final role = prefs.getString('loggedInRole');
  
  if (role != null) {
    AppSession.loggedInRole = role;
    final store = AtpsStore();
    store.unitId.value = prefs.getString('unitId') ?? "";
    store.driverName.value = prefs.getString('driverName') ?? "";
    store.driverPhone.value = prefs.getString('driverPhone') ?? "";
  }

  runApp(AtpsApp(initialRole: role));
}

class AtpsApp extends StatelessWidget {
  final String? initialRole;
  const AtpsApp({super.key, this.initialRole});

  @override
  Widget build(BuildContext context) {
    Widget initialScreen = const LandingScreen();
    if (initialRole == 'ADMIN') {
      initialScreen = const AdminDashboard();
    } else if (initialRole == 'DRIVER') {
      initialScreen = const DriverDashboard();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'APTSC Traffic Control',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        cardColor: const Color(0xFF151B25),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: initialScreen,
    );
  }
}

// ---------------- SCREEN 1: LANDING ----------------
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(LucideIcons.siren, color: Color(0xFFFF4D4D)),
            SizedBox(width: 10),
            Text(
              "APTSC",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00CC66).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00CC66).withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              "System Online",
              style: TextStyle(
                color: Color(0xFF00CC66),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                "Select Your Role",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Access the dashboard designed for your responsibilities",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 50),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _buildRoleCard(
                    context,
                    "Ambulance Driver",
                    "Request priority at signals & track routes.",
                    Icons.local_hospital,
                    Colors.redAccent,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(role: "DRIVER"),
                        ),
                      );
                    },
                  ),

                  _buildRoleCard(
                    context,
                    "Administrator",
                    "Verify emergency requests & control signals.",
                    LucideIcons.shield,
                    Colors.blueAccent,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(role: "ADMIN"),
                        ),
                      );
                    },
                  ),

                  _buildRoleCard(
                    context,
                    "Guest Viewer",
                    "View real-time system status...",
                    LucideIcons.eye,
                    Colors.cyanAccent,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GuestDashboard(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget safely inside the LandingScreen class
  Widget _buildRoleCard(
    BuildContext context,
    String title,
    String desc,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 350,
      child: Material(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Access Dashboard →",
                  style: TextStyle(color: Color(0xFF007BFF)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
