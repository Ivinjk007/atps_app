import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'atps_store.dart';
import 'login_screen.dart'; 
import 'main.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AtpsStore store = AtpsStore();

  @override
  void initState() {
    super.initState();
    store.fetchRegisteredUnits();
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
      child: Watch(
        (_) => _buildStatCard(
          "Active Emergencies",
          "${store.activeEmergenciesCount.value}",
          Colors.redAccent,
          LucideIcons.siren,
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
        onTap: () => _showUnitDetails(context), // Shows the Kochi unit details popup
        child: Watch(
          (_) => _buildStatCard(
            "Available units", // Localized label for Kochi Ernakulam
            "${store.registeredUnitsCount.value}", // Real count from your database
            Colors.greenAccent,
            LucideIcons.checkCircle,
          ),
        ),
      ),
    ),
    const SizedBox(width: 16),
    // --- CONTROLLED SIGNALS (Manual Junction Overrides) ---
    Expanded(
      child: _buildStatCard(
        "Controlled Signals",
        "28", // Updated to a realistic count for Kochi junctions
        Colors.blueAccent,
        LucideIcons.activity,
      ),
    ),
  ],
),
const SizedBox(height: 32),

            // 2. EMERGENCY REQUESTS
              _sectionHeader("Incoming Requests"),
              const SizedBox(height: 16),

              Watch((context) {
                final requests = store.emergencyRequests.value;

                if (requests.isEmpty) {
                  return const Text(
                    "No active requests",
                    style: TextStyle(color: Colors.grey),
                  );
                }

                return Column(
                  children: requests
                      .map((req) => _buildRequestCard(req, store))
                      .toList(),
                );
              }),

              const SizedBox(height: 32),


            // 3. TRAFFIC SIGNAL GRID
            _sectionHeader("Traffic Signal Manual Override"),
            const SizedBox(height: 16),

            Watch((context) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: store.trafficSignals.length,
                itemBuilder: (context, index) {
                  final sig = store.trafficSignals[index];
                  return _buildSignalCard(sig, store);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

 void _showUnitDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151B25),
        title: const Text(
          "Registered Database Units",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Watch((_) {
            final units = store.registeredUnits.value;

            if (units.isEmpty) {
              return const Text(
                "No users found in database.",
                style: TextStyle(color: Colors.grey),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: units.length,
              itemBuilder: (context, index) {
                final user = units[index];
                void _showUnitDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151B25),
        title: const Text(
          "Registered Database Units",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Watch((_) {
            final units = store.registeredUnits.value;

            if (units.isEmpty) {
              return const Text(
                "No users found in database.",
                style: TextStyle(color: Colors.grey),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: units.length,
              itemBuilder: (context, index) {
                final user = units[index];
                return ListTile(
                  leading: const Icon(Icons.person,
                      color: Colors.blueAccent),
                  title: Text(
                    user['unit_id'] ?? "Unknown Unit",
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "Contact: ${user['phone'] ?? 'N/A'}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              },
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
              },
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
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
          if (req['status'] == 'PENDING') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        store.denyRequest(req['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side:
                          const BorderSide(color: Colors.red),
                    ),
                    child: const Text("Deny"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        store.approveRequest(req['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      "Approve",
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

  // ---------- SIGNAL CARD ----------
  Widget _buildSignalCard(Map<String, dynamic> sig, AtpsStore store) {
    final bool isGreen = sig['status'] == 'GREEN';
    final bool isOnline = sig['online'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGreen
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.traffic,
                color: isOnline
                    ? (isGreen ? Colors.green : Colors.red)
                    : Colors.grey,
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isGreen,
                  activeColor: Colors.green,
                  inactiveTrackColor:
                      Colors.red.withValues(alpha: 0.3),
                  onChanged: isOnline
                      ? (_) =>
                          store.toggleSignalManual(sig['id'])
                      : null,
                ),
              )
            ],
          ),
          const Spacer(),
          Text(
            sig['name'],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            isOnline
                ? (isGreen ? "GREEN" : "RED")
                : "OFFLINE",
            style: TextStyle(
              color: isOnline
                  ? (isGreen ? Colors.green : Colors.red)
                  : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

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