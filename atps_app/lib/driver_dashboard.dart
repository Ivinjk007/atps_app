import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'atps_store.dart';
import 'login_screen.dart'; 
import 'main.dart';         

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final store = AtpsStore();
  
  // New Priority State
  String _selectedPriority = "Critical";
  // LOGOUT FUNCTION
  void _logout() async {
    AppSession.loggedInRole = null; // Clear the saved session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedInRole');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LandingScreen()),
        (route) => false, // Destroy the navigation history
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
     appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E14),
        elevation: 0,
        title: const Text(
          "Driver Dashboard",
          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        // We keep the back button if you want it, but add the logout button on the right:
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Logout",
            onPressed: _logout, // Calls the logout function
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // STATUS BAR
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF151B25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "((o)) Connected",
                    style: TextStyle(color: Color(0xFF00CC66), fontWeight: FontWeight.bold),
                  ),
                  Watch((context) => Text(
                        "Unit: ${store.unitId.value}",
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 40),

            const Text(
              "Press to request traffic signal priority.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 30),

            // BIG CIRCULAR REQUEST BUTTON
            Watch(
              (context) => GestureDetector(
                onTap: () => _handlePriorityRequest(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: store.status.value == "GREEN"
                          ? const [Color(0xFF00CC66), Color(0xFF007A3D)]
                          : const [Color(0xFF1F2937), Color(0xFF111827)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        // Updated to withValues to fix your VS Code deprecation warnings
                        color: store.statusColor.value.withValues(alpha: 0.4),
                        blurRadius: 50,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (store.isLoading.value)
                        const CircularProgressIndicator(color: Colors.white)
                      else ...[
                        Icon(
                          LucideIcons.siren,
                          size: 60,
                          color: store.status.value == "GREEN" ? Colors.white : Colors.white54,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          store.status.value == "GREEN" ? "GRANTED" : "REQUEST",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.white,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 50),

            // NEW PRIORITY SELECTOR 
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF151B25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Mission Priority",
                    style: TextStyle(color: Colors.blue, fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0E14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPriority,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF151B25),
                        icon: const Icon(LucideIcons.chevronDown, color: Colors.grey),
                        items: ['Critical', 'Non-Critical']
                            .map((priority) => DropdownMenuItem(
                                  value: priority,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 16,
                                        color: _getPriorityColor(priority),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        priority,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedPriority = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Watch((context) => Column(
              children: [
                if (store.status.value == "GREEN")
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 20),
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmCompletion(context),
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: const Text(
                        "COMPLETE JOURNEY",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00CC66),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => store.reset(isFalseAlarm: true),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                    label: const Text(
                      "Cancel Request (False Alarm)",
                      style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  // --- LOCATION PROVIDED BY GPS MODULE ---
  void _handlePriorityRequest(BuildContext context) {
    if (store.status.value == "GREEN") return; // Already requested

    // Location is handled by external GPS modules, so we bypass manual user input
    // and immediately activate the priority sequence.
    store.requestPriority("Live GPS Tracking", "Assigned Hospital");
  }

  // Helper method to color-code the priority dropdown
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical': return const Color(0xFFFF4D4D); // Red
      case 'Non-Critical': return const Color(0xFF00CC66); // Green
      default: return Colors.white;
    }
  }

  void _confirmCompletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151B25),
        title: const Text("Complete Journey?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to end this emergency journey and reset signals?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              store.reset(isFalseAlarm: false); // Effectively completes the journey
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00CC66)),
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}