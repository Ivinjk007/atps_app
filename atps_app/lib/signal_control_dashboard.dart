import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'atps_store.dart';
import 'dart:async';

class SignalControlDashboard extends StatefulWidget {
  const SignalControlDashboard({super.key});

  @override
  State<SignalControlDashboard> createState() => _SignalControlDashboardState();
}

class _SignalControlDashboardState extends State<SignalControlDashboard> {
  final AtpsStore store = AtpsStore();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    store.fetchSignals(hideLoading: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timer.tick % 2 == 0) {
        store.fetchSignals(hideLoading: true);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _calculateRemainingSeconds(String? lastUpdatedStr, String status, String mode) {
    if (lastUpdatedStr == null || mode == 'MANUAL') return 0;
    try {
      String str = lastUpdatedStr;
      if (!str.endsWith('Z')) str += 'Z';
      final lastUpdated = DateTime.parse(str).toUtc();
      final now = DateTime.now().toUtc();
      final elapsed = now.difference(lastUpdated).inSeconds;

      int totalDuration = 0;
      if (status == 'GREEN') totalDuration = 7;
      else if (status == 'YELLOW') totalDuration = 2;
      else if (status == 'RED') totalDuration = 1;

      final remaining = totalDuration - elapsed;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151B25),
        title: const Text("Traffic Signal Control",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Watch((_) {
          final signals = store.trafficSignals.value;

          if (signals.isEmpty) {
            return const Center(
              child: Text(
                "No traffic signals registered.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          double screenWidth = MediaQuery.of(context).size.width;
          int columns = screenWidth > 600 ? 2 : 1;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 380, // taller to fit lane indicators + buttons
            ),
            itemCount: signals.length,
            itemBuilder: (context, index) {
              return _buildEnhancedSignalCard(signals[index], store);
            },
          );
        }),
      ),
    );
  }

  Widget _buildEnhancedSignalCard(Map<String, dynamic> sig, AtpsStore store) {
    final status = sig['status'] ?? 'RED';
    final mode = sig['mode'] ?? 'AUTO';
    final isOnline = sig['online'] == true;
    final int activeLight = sig['active_light'] ?? 1; // NEW: which lane is active
    final int remainingSeconds =
        _calculateRemainingSeconds(sig['last_updated'], status, mode);

    Color statusColor;
    if (status == 'GREEN') {
      statusColor = Colors.greenAccent;
    } else if (status == 'YELLOW') {
      statusColor = Colors.orangeAccent;
    } else {
      statusColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? statusColor.withValues(alpha: 0.3) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP ROW: icon + timer/HOLD badge ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.traffic,
                  color: isOnline ? statusColor : Colors.grey, size: 28),
              if (isOnline)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mode == 'MANUAL' ? "HOLD" : "${remainingSeconds}s",
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ── JUNCTION NAME + MODE ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Junction Name:",
                  style: TextStyle(color: Colors.grey, fontSize: 10)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: mode == 'MANUAL'
                      ? Colors.orangeAccent.withValues(alpha: 0.1)
                      : Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Mode: $mode",
                  style: TextStyle(
                      color: mode == 'MANUAL'
                          ? Colors.orangeAccent
                          : Colors.lightBlueAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Text(
            sig['name'] ?? "Unknown",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Text("Current Signal:",
              style: TextStyle(color: Colors.grey, fontSize: 10)),
          Text(
            isOnline ? status : "OFFLINE",
            style: TextStyle(
                color: isOnline ? statusColor : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),

          const SizedBox(height: 12),

          // ── 4 LANE INDICATORS ──
          // Shows which lane is active and its current color
          // All inactive lanes are always RED
          if (isOnline)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (i) {
                final laneNumber = i + 1; // lanes are 1-indexed
                final isActiveLane = laneNumber == activeLight;

                // Active lane shows current status color
                // All other lanes are RED
                Color laneColor;
                if (isActiveLane) {
                  if (status == 'GREEN') laneColor = Colors.greenAccent;
                  else if (status == 'YELLOW') laneColor = Colors.orangeAccent;
                  else laneColor = Colors.redAccent;
                } else {
                  laneColor = Colors.redAccent; // inactive lanes always RED
                }

                return Column(
                  children: [
                    // The light circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActiveLane
                            ? laneColor
                            : laneColor.withValues(alpha: 0.15), // dim if inactive
                        border: Border.all(
                          color: laneColor.withValues(alpha: 0.6),
                          width: isActiveLane ? 2 : 1,
                        ),
                        boxShadow: isActiveLane
                            ? [
                                BoxShadow(
                                  color: laneColor.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Lane label
                    Text(
                      ["N", "E", "S", "W"][i],
                      style: TextStyle(
                        color: isActiveLane ? Colors.white : Colors.grey,
                        fontSize: 10,
                        fontWeight: isActiveLane
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),

          const SizedBox(height: 12),

          // ── MANUAL CONTROLS ──
          if (isOnline) ...[
            // Lane selector — only visible in MANUAL mode
            if (mode == 'MANUAL')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ["N", "E", "S", "W"].asMap().entries.map((entry) {
                  final laneIndex = entry.key + 1;
                  final laneLabel = entry.value;
                  final isSelected = activeLight == laneIndex;
                  return GestureDetector(
                    onTap: () => store.setActiveLight(sig['id'], laneIndex),
                    child: Container(
                      width: 44,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blueAccent
                            : Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Center(
                        child: Text(
                          laneLabel,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 8),

            // Color buttons + AUTO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _colorButton("RED", Colors.redAccent, store, sig['id'], status),
                _colorButton("YELLOW", Colors.orangeAccent, store, sig['id'], status),
                _colorButton("GREEN", Colors.greenAccent, store, sig['id'], status),
                GestureDetector(
                  onTap: () => store.toggleSignalManual(sig['id'], "AUTO"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: mode == 'AUTO' ? Colors.blueAccent : Colors.transparent,
                      border: Border.all(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "AUTO",
                      style: TextStyle(
                          color: mode == 'AUTO' ? Colors.white : Colors.blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _colorButton(String targetColor, Color displayColor, AtpsStore store,
      String id, String currentStatus) {
    bool isActive = currentStatus == targetColor;
    return GestureDetector(
      onTap: () => store.toggleSignalManual(id, targetColor),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? displayColor
              : displayColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? Colors.white
                : displayColor.withValues(alpha: 0.5),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: displayColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
      ),
    );
  }
}
