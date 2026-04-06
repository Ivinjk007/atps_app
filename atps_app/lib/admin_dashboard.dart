import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'atps_store.dart';
import 'login_screen.dart'; 
import 'main.dart';
import 'signal_control_dashboard.dart';
import 'dart:async';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AtpsStore store = AtpsStore();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    store.fetchRegisteredUnits();
    store.fetchSignals();
    store.fetchEmergencyRequests();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        store.fetchSignals(hideLoading: true);
        store.fetchEmergencyRequests(hideLoading: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _showAddSignalDialog(BuildContext context) {
  final idController = TextEditingController();
  final nameController = TextEditingController();
  final latController = TextEditingController();
  final lonController = TextEditingController();
  final espController = TextEditingController();
  final radiusController = TextEditingController(text: "500");
  String selectedMode = 'AUTO';

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: const Color(0xFF151B25),
        title: const Text(
          "Add New Controlled Signal",
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Junction ID (e.g. J-01)",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Junction Name",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              TextField(
                controller: latController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Latitude",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              TextField(
                controller: lonController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Longitude",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              TextField(
                controller: espController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "ESP32 Controller ID",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              TextField(
                controller: radiusController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Trigger Radius (meters)",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                dropdownColor: const Color(0xFF151B25),
                value: selectedMode,
                items: ["AUTO", "MANUAL"]
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    selectedMode = val!;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              bool success = await store.addNewSignal(
                idController.text,
                nameController.text,
                latController.text,
                lonController.text,
                espController.text,
                radiusController.text,
                selectedMode,
              );

              if (success) {
                Navigator.pop(context);
              }
            },
            child: const Text("Add Signal"),
          ),
        ],
      ),
    ),
  );
}
  @override
Widget build(BuildContext context) {
  return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E14),
        title: const Text("Admin Dashboard"),
       actions: [
  IconButton(
    icon: const Icon(Icons.history, color: Colors.orangeAccent),
    tooltip: "History Log",
    onPressed: () => _showHistoryLog(context),
  ),
  IconButton(
    icon: const Icon(Icons.add_road, color: Colors.greenAccent),
    tooltip: "Add Signal",
    onPressed: () => _showAddSignalDialog(context),
  ),
  IconButton(
    icon: const Icon(Icons.logout, color: Colors.blueAccent),
    tooltip: "Logout",
    onPressed: () {
      AppSession.loggedInRole = null;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LandingScreen(),
        ),
        (route) => false,
      );
    },
  ),
  const SizedBox(width: 8),
],
),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. STATS ROW (Kochi Control Center)
Row(
  children: [
    Expanded(
      child: GestureDetector(
        onTap: () => _showActiveEmergencyDetails(context),
        child: Watch(
          (_) => _buildStatCard(
            "Active Emergencies",
            "${store.activeEmergenciesCount.value}",
            Colors.redAccent,
            LucideIcons.siren,
          ),
        ),
      ),
    ),
    const SizedBox(width: 16),
    Expanded(
      child: GestureDetector(
        onTap: () => _showUnitDetails(context),
        child: Watch(
          (_) => _buildStatCard(
            "Registered Units",
            "${store.registeredUnitsCount.value}",
            Colors.greenAccent,      // ✅ Color first
            LucideIcons.users,       // ✅ Icon second
          ),
        ),
      ),
    ),
  ],
),
const SizedBox(height: 16),
Row(
  children: [
    // --- KL-07 UNITS (Shows real DB count & opens details on click) ---
    Expanded(
      child: GestureDetector(
        onTap: () => _showUnitDetails(context, onlyAvailable: true), // Shows only available units
        child: Watch(
          (_) => _buildStatCard(
            "Available units", 
            "${store.availableUnitsCount.value}", 
            Colors.greenAccent,
            LucideIcons.checkCircle,
          ),
        ),
      ),
    ),
    const SizedBox(width: 16),
    // --- CONTROLLED SIGNALS (Manual Junction Overrides) ---
    Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SignalControlDashboard()),
          );
        },
        child: Watch((_) => _buildStatCard(
          "Controlled Signals",
          "${store.trafficSignals.length}", 
          Colors.blueAccent,
          LucideIcons.activity,
        )),
      ),
    ),
  ],
),
const SizedBox(height: 32),

            // 2. EMERGENCY REQUESTS
              _sectionHeader("Incoming Requests"),
              const SizedBox(height: 16),

              Watch((context) {
                final allRequests = store.emergencyRequests.value;

                final activeRequests = allRequests.where((req) => req['status'] == 'APPROVED' || req['status'] == 'PENDING').toList();
                final completedRequests = allRequests.where((req) => req['status'] == 'COMPLETED' || req['status'] == 'DENIED').toList();

                final displayedRequests = [
                  ...activeRequests,
                  ...completedRequests.take(3)
                ];

                if (displayedRequests.isEmpty) {
                  return const Text(
                    "No active or recent requests",
                    style: TextStyle(color: Colors.grey),
                  );
                }

                return Column(
                  children: displayedRequests
                      .map((req) => _buildRequestCard(req, store))
                      .toList(),
                );
              }),

              const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

 void _showActiveEmergencyDetails(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF151B25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        "Active Emergencies Details",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Watch((_) {
          final activeReqs = store.emergencyRequests.value.where((req) => req['status'] == 'APPROVED').toList();

          if (activeReqs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "No active emergencies found.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            itemCount: activeReqs.length,
            itemBuilder: (context, index) {
              final req = activeReqs[index];
              final unitId = req['unit'];
              
              // Find driver details from registeredUnits
              final unitsList = store.registeredUnits.value;
              final userMap = unitsList.firstWhere(
                (u) => u['unit_id'] == unitId, 
                orElse: () => <String, dynamic>{}
              );
              
              final name = userMap['name'] ?? "Unknown Driver";
              final phone = userMap['phone'] ?? "Not Provided";

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          unitId ?? "Unknown Unit",
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "ACTIVE",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    _detailRow(Icons.person, "Driver", name),
                    const SizedBox(height: 8),
                    _detailRow(Icons.phone, "Contact", phone),
                    const SizedBox(height: 8),
                    _detailRow(Icons.location_on, "Location", req['location'] ?? "Unknown"),
                  ],
                ),
              );
            },
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(color: Colors.blueAccent)),
        ),
      ],
    ),
  );
}

 void _showUnitDetails(BuildContext context, {bool onlyAvailable = false}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF151B25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        onlyAvailable ? "Available Ambulance Units" : "All Registered Units",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Watch((_) {
          final units = store.registeredUnits.value;

          // Filter out units that are currently on an APPROVED run
          final targetUnitsList = onlyAvailable ? units.where((user) {
            bool isBusy = store.emergencyRequests.value.any(
              (req) => req['unit'] == user['unit_id'] && req['status'] == 'APPROVED'
            );
            return !isBusy;
          }).toList() : units;

          if (targetUnitsList.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                onlyAvailable ? "No available drivers found in database." : "No registered drivers found in database.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            itemCount: targetUnitsList.length,
            itemBuilder: (context, index) {
              final user = targetUnitsList[index];

              // Check if this specific driver is currently on an APPROVED run
              bool isBusy = store.emergencyRequests.value.any(
                (req) => req['unit'] == user['unit_id'] && req['status'] == 'APPROVED'
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBusy ? Colors.redAccent.withValues(alpha: 0.3) : Colors.greenAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          user['unit_id'] ?? "Unknown Unit",
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isBusy ? Colors.redAccent.withValues(alpha: 0.1) : Colors.greenAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isBusy ? "BUSY" : "AVAILABLE",
                            style: TextStyle(
                              color: isBusy ? Colors.redAccent : Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    _detailRow(Icons.person, "Driver", user['name'] ?? "Unknown Driver"),
                    const SizedBox(height: 8),
                    _detailRow(Icons.phone, "Contact", user['phone'] ?? "Not Provided"),
                  ],
                ),
              );
            },
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(color: Colors.blueAccent)),
        ),
      ],
    ),
  );
}


// Helper widget for clean rows
Widget _detailRow(IconData icon, String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 14, color: Colors.grey),
      ),
      const SizedBox(width: 8),
      Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Expanded(
        child: Text(
          value, 
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          softWrap: true,
        ),
      ),
    ],
  );
  }

 // --- NEW: HISTORY LOG DIALOG ---
 void _showHistoryLog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF151B25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.history, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Emergency Request History",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Watch((_) {
          final completedReqs = store.emergencyRequests.value.where((req) => req['status'] == 'COMPLETED').toList();

          if (completedReqs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "No completed requests in history.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: completedReqs.length,
              itemBuilder: (context, index) {
                // Show newest first
                final req = completedReqs[completedReqs.length - 1 - index];
                final unitId = req['unit'];

                // Attempt to find driver name
                final unitsList = store.registeredUnits.value;
                final userMap = unitsList.firstWhere(
                  (u) => u['unit_id'] == unitId, 
                  orElse: () => <String, dynamic>{}
                );
                final name = userMap['name'] ?? "Unknown Driver";

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orangeAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            unitId ?? "Unknown Unit",
                            style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "RESOLVED",
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 20),
                      _detailRow(Icons.person, "Driver", name),
                      const SizedBox(height: 8),
                      _detailRow(Icons.route, "Path Taken", req['location'] ?? "Unknown"),
                    ],
                  ),
                );
              },
            ),
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(color: Colors.orangeAccent)),
        ),
      ],
    ),
  );
}

  // ---------- REQUEST CARD ----------
  Widget _buildRequestCard(Map<String, dynamic> req, AtpsStore store) {
    Color statusColor;
    switch (req['status']) {
      case 'PENDING':
        statusColor = Colors.orange;
        break;
      case 'APPROVED':
        statusColor = Colors.green;
        break;
      case 'DENIED':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  req['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                req['eta'],
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    Colors.blue.withValues(alpha: 0.1),
                radius: 20,
                child: const Icon(
                  Icons.local_hospital,
                  size: 20,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    req['unit'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    req['location'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (req['status'] == 'APPROVED') ...[
  const SizedBox(height: 16),
  Row(
    children: [
      Expanded(
        child: ElevatedButton(
          onPressed: () => store.denyRequest(req['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text(
            "Reject / Stop",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    ],
  )
]
        ],
      ),
    );
  }

  // Removed deprecated _buildSignalCard inline UI component

  // ---------- STAT CARD ----------
  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )
      ],
    );
  }
}