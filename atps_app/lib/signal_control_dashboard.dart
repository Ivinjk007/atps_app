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
    // Start a 1-second UI refresh timer for countdowns and periodic polling
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timer.tick % 2 == 0) {
        // Poll backend every 2 seconds to keep last_updated and status in sync
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
    if (lastUpdatedStr == null || mode == 'MANUAL') return 0; // Manual overrides halt timer
    try {
      String str = lastUpdatedStr;
      if (!str.endsWith('Z')) str += 'Z'; // Force UTC representation if backend sends naive ISO
      final lastUpdated = DateTime.parse(str).toUtc();
      final now = DateTime.now().toUtc();
      final elapsed = now.difference(lastUpdated).inSeconds;

      int totalDuration = 0;
      if (status == 'RED') totalDuration = 60;
      else if (status == 'GREEN') totalDuration = 60;
      else if (status == 'YELLOW') totalDuration = 20;
      
      final remaining = totalDuration - elapsed;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // Deep space blue/black
      appBar: AppBar(
        backgroundColor: const Color(0xFF151B25),
        title: const Text("Traffic Signal Control", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              mainAxisExtent: 220, // slightly taller for bigger buttons
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
    final int remainingSeconds = _calculateRemainingSeconds(sig['last_updated'], status, mode);

    Color statusColor;
    if (status == 'GREEN') statusColor = Colors.greenAccent;
    else if (status == 'YELLOW') statusColor = Colors.orangeAccent;
    else statusColor = Colors.redAccent;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.traffic,
                color: isOnline ? statusColor : Colors.grey,
                size: 28,
              ),
              if (isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mode == 'MANUAL' ? "HOLD" : "${remainingSeconds}s",
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Junction Name:",
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: mode == 'MANUAL' ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Mode: $mode",
                  style: TextStyle(
                    color: mode == 'MANUAL' ? Colors.orangeAccent : Colors.lightBlueAccent, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ],
          ),
          Text(
            sig['name'] ?? "Unknown",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          const Text(
            "Current Signal:",
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          Text(
            isOnline ? status : "OFFLINE",
            style: TextStyle(
              color: isOnline ? statusColor : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          // Custom explicit overrides
          if (isOnline)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _colorButton("RED", Colors.redAccent, store, sig['id'], status),
                _colorButton("YELLOW", Colors.orangeAccent, store, sig['id'], status),
                _colorButton("GREEN", Colors.greenAccent, store, sig['id'], status),
                // Mode restore button
                GestureDetector(
                  onTap: () => store.toggleSignalManual(sig['id'], "AUTO"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: mode == 'AUTO' ? Colors.blueAccent : Colors.transparent,
                      border: Border.all(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text("AUTO", style: TextStyle(color: mode == 'AUTO' ? Colors.white : Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            )
        ],
      ),
    );
  }

  Widget _colorButton(String targetColor, Color displayColor, AtpsStore store, String id, String currentStatus) {
    bool isActive = currentStatus == targetColor;
    return GestureDetector(
      onTap: () => store.toggleSignalManual(id, targetColor),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? displayColor : displayColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? Colors.white : displayColor.withValues(alpha: 0.5),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: displayColor.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ] : [],
        ),
      ),
    );
  }
}
