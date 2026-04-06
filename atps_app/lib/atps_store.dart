import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'traffic_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AtpsStore {
  // Singleton pattern to ensure state is shared across dashboards during local testing
  static final AtpsStore _instance = AtpsStore._internal();
  factory AtpsStore() => _instance;
  AtpsStore._internal();

  final _api = TrafficService();

  // Holds ambulance units from DB
final registeredUnits =
    signal<List<Map<String, dynamic>>>([]);

// Counts registered units
late final registeredUnitsCount =
    computed(() => registeredUnits.value.length);

// Counts available units (not in active emergency)
late final availableUnitsCount = computed(() {
  final totalUnits = registeredUnits.value.length;

  final busyUnits = emergencyRequests.value
      .where((req) => req['status'] == 'APPROVED')
      .length;

  return totalUnits - busyUnits;
});
 

  // Counts approved emergencies
  late final activeEmergenciesCount =
      computed(() =>
          emergencyRequests.value
              .where((req) =>
                  req['status'] == 'APPROVED')
              .length);
      Future<void> fetchRegisteredUnits({bool hideLoading = false}) async {
  if (!hideLoading) isLoading.value = true;

  try {
    final response = await http.get(
      Uri.parse("${TrafficService.serverUrl}/units"),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      registeredUnits.value =
          List<Map<String, dynamic>>.from(data);
    }
  } catch (e) {
    print("Fetch error: \$e");
  } finally {
    if (!hideLoading) isLoading.value = false;
  }
}

  Future<void> fetchEmergencyRequests({bool hideLoading = false}) async {
    if (!hideLoading) isLoading.value = true;

    try {
      final response = await http.get(
        Uri.parse("${TrafficService.serverUrl}/admin/requests"),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        
        final currentRequests = data.map((req) => {
          "id": req["id"].toString(),
          "unit": req["unit_id"],
          "location": req["destination"] ?? "Unknown",
          "status": req["status"],
          "eta": "Unknown",
        }).toList();

        emergencyRequests.value = List<Map<String, dynamic>>.from(currentRequests);
      }
    } catch (e) {
      print("Fetch emergency requests error: \$e");
    } finally {
      if (!hideLoading) isLoading.value = false;
    }
  }

  // =========================
  // DRIVER STATE
  // =========================

  final status = signal("RED");
  final isLoading = signal(false);
  final unitId = signal("AMB-042");
  final driverName = signal("");
  final driverPhone = signal("");
  final username = signal("");  
  final eta = signal("8:45");

  // =========================
  // ADMIN STATE
  // =========================

  // Inside your AtpsStore class in lib/atps_store.dart

final emergencyRequests = signal<List<Map<String, dynamic>>>([]);

final trafficSignals = listSignal<Map<String, dynamic>>([]);

  Future<void> fetchSignals({bool hideLoading = false}) async {
    try {
      final response = await http.get(Uri.parse("${TrafficService.serverUrl}/admin/signals"));
      
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        final formattedSignals = data.map((sig) => {
  "id": sig["junction_id"],
  "name": sig["junction_name"],
  "status": sig["current_status"],
  "mode": sig["mode"] ?? "AUTO",
  "active_light": sig["active_light"] ?? 1,  // ← ADD THIS
  "battery_level": sig["battery_level"] ?? 100,
  "last_updated": sig["last_updated"],
  "online": true,
}).toList();
        trafficSignals.value = List<Map<String, dynamic>>.from(formattedSignals);
      }
    } catch (e) {
      print("Fetch signals error: \$e");
    }
  }

  // =========================
  // COMPUTED VALUES
  // =========================

  late final statusColor = computed(
      () => status.value == "GREEN"
          ? const Color(0xFF00CC66)
          : const Color(0xFFFF4D4D));

  late final statusText = computed(
      () => status.value == "GREEN"
          ? "PRIORITY ACTIVE"
          : "NORMAL OPERATION");

  late final signalText =
      computed(() => status.value == "GREEN" ? "GREEN" : "RED");


  // =========================
  // TRAFFIC ACTIONS
  // =========================

  Future<void> requestPriority(String fromLocation, String toLocation, String priority) async {
    if (status.value == "GREEN") return;

    isLoading.value = true;
    final res = await _api.requestGreen(unitId.value, username.value, driverName.value, fromLocation, toLocation, driverPhone.value, priority);
    
    // Auto-update active emergency cases locally for instant feedback
    final currentRequests = List<Map<String, dynamic>>.from(emergencyRequests.value);
    currentRequests.add({
      "id": res['success'] == true ? res['request_id'] : DateTime.now().millisecondsSinceEpoch.toString(),
      "unit": unitId.value,
      "location": "$fromLocation ➔ $toLocation",
      "status": "APPROVED",
      "eta": eta.value,
    });
    emergencyRequests.value = currentRequests;

    status.value = "GREEN";
    isLoading.value = false;
  }

  Future<void> reset({bool isFalseAlarm = false}) async {
    isLoading.value = true;
    await _api.resetSignal(unitId.value);

    // Auto-remove from active emergencies locally without mutating the old map
    final currentRequests = List<Map<String, dynamic>>.from(emergencyRequests.value);
    List<Map<String, dynamic>> updatedRequests = [];
    
    for (var req in currentRequests) {
      if (req['unit'] == unitId.value && req['status'] == 'APPROVED') {
        if (isFalseAlarm) {
           _api.deleteRequest(req['id']);
        } else {
           final updatedReq = Map<String, dynamic>.from(req);
           updatedReq['status'] = 'COMPLETED';
           _api.updateRequestStatus(req['id'], 'COMPLETED');
           updatedRequests.add(updatedReq);
        }
      } else {
        updatedRequests.add(req);
      }
    }
    // Deep equality check will now see the difference and trigger UI updates instantly!
    emergencyRequests.value = updatedRequests;

    status.value = "RED";
    isLoading.value = false;
  }

  // --- ACTIONS: ADMIN ---

  Future<void> checkMyRequestStatus() async {
    if (status.value != "GREEN") return;
    
    final currentStatus = await _api.checkDriverStatus(unitId.value);
    
    // If the Admin denied or completed the request remotely
    if (currentStatus == "COMPLETED" || currentStatus == "DENIED") {
      status.value = "RED";
      
      // Auto-remove from active emergencies locally so the dashboard UI and counters stay correct
      final currentRequests = List<Map<String, dynamic>>.from(emergencyRequests.value);
      currentRequests.removeWhere((req) => req['unit'] == unitId.value && req['status'] == 'APPROVED');
      emergencyRequests.value = currentRequests;
    }
  }

  void denyRequest(String requestId) {
    final currentRequests = List<Map<String, dynamic>>.from(emergencyRequests.value);
    final index = currentRequests.indexWhere((req) => req['id'] == requestId);
    
    if (index != -1) {
      final updatedReq = Map<String, dynamic>.from(currentRequests[index]);
      updatedReq['status'] = 'DENIED';
      
      currentRequests[index] = updatedReq;
      
      _api.updateRequestStatus(requestId, 'DENIED');
      // Triggers immediate UI rebuild since we passed a new immutable copy
      emergencyRequests.value = currentRequests; 
    }
  }

  Future<void> toggleSignalManual(String junctionId, String newColor) async {
    try {
      final index = trafficSignals.value
          .indexWhere((element) => element['id'] == junctionId);

      if (index == -1) return;

      var sig = Map<String, dynamic>.from(trafficSignals.value[index]);
      final oldMode = sig['mode'];
      final oldStatus = sig['status'];

      // Update UI immediately (optimistic UI update)
      if (newColor == 'AUTO') {
        sig['mode'] = 'AUTO';
      } else {
        sig['mode'] = 'MANUAL';
        sig['status'] = newColor;
      }
      trafficSignals.value[index] = sig;
      trafficSignals.value = List.from(trafficSignals.value); // Trigger signals reactivity

      // Send command to Flask backend
      final response = await http.post(
        Uri.parse("${TrafficService.serverUrl}/admin/signal_override"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "junction_id": junctionId,
          "color": newColor
        }),
      );

      if (response.statusCode != 200) {
        print("Backend failed to process override. Reverting UI.");
        sig['mode'] = oldMode;
        sig['status'] = oldStatus;
        trafficSignals.value[index] = sig;
        trafficSignals.value = List.from(trafficSignals.value);
      }

    } catch (e) {
      print("Signal override network error: $e");
      // Optionally could implement flutter toast/snackbar here but print is sufficient for debugging
    }
  }
  // --- ACTIONS: AUTHENTICATION ---

  // 1. Login
  Future<bool> login(String username, String password, String role) async {
    isLoading.value = true;
    final result = await _api.login(username, password, role);
    isLoading.value = false;

    if (result['success'] == true) {
      if (result['user'] != null && result['user']['unit_id'] != null) {
        unitId.value = result['user']['unit_id'];
        driverName.value = result['user']['name'] ?? "";
        driverPhone.value = result['user']['phone'] ?? "";
        this.username.value = result['user']['username'] ?? "";
      }
      return true;
    } else {
      print("Login failed: ${result['message']}");
      return false;
    }
  }

 // 1. Create Driver Account (Updated)
  // Returns NULL if success, or Error Message string if failed
 Future<bool> createAccount(
  String name,
  String username,
  String password,
  String unitId,
  String phone,
  String role,
) async {

  isLoading.value = true;

  final result = await _api.signup(
    name,
    username,
    password,
    unitId,
    phone,
    role,
  );

  isLoading.value = false;

  if (result['success'] == true) {
    return true;
  } else {
    throw Exception(result['message']);
  }
}
  // 2. Create Admin Account (REAL SERVER VERSION)
Future<bool> createAdminAccount(
  String name,
  String username,
  String password,
  String cyberId,
) async {

  isLoading.value = true;

  //  CALL BACKEND
  final result = await _api.signup(
    name,
    username,
    password,
    cyberId,
    "",
    "ADMIN",
  );

  isLoading.value = false;

  if (result['success'] == true) {
    return true;
  } else {
    throw Exception(result['message']);
  }
}
Future<bool> addNewSignal(
  String junctionId,
  String junctionName,
  String lat,
  String lon,
  String esp32Id,
  String triggerRadius,
  String mode,
) async {
  try {
    final response = await http.post(
      Uri.parse("${TrafficService.serverUrl}/admin/add_signal"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "junction_id": junctionId,
        "junction_name": junctionName,
        "landmark": junctionName,
        "lat": lat,
        "lon": lon,
        "esp32_id": esp32Id,
        "trigger_radius": triggerRadius,
        "mode": mode,
      }),
    );

    if (response.statusCode == 201) {
      // Refresh the backend signals strictly
      await fetchSignals(hideLoading: true);
      return true;
    } else {
      print("Add signal failed: ${response.body}");
      return false;
    }
  } catch (e) {
    print("Add signal error: $e");
    return false;
  }
}
Future<void> setActiveLight(String junctionId, int lightId) async {
    try {
      final index = trafficSignals.value
          .indexWhere((element) => element['id'] == junctionId);
      if (index == -1) return;

      var sig = Map<String, dynamic>.from(trafficSignals.value[index]);
      sig['active_light'] = lightId;
      trafficSignals.value[index] = sig;
      trafficSignals.value = List.from(trafficSignals.value);

      await http.post(
        Uri.parse("${TrafficService.serverUrl}/admin/set_active_light"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "junction_id": junctionId,
          "active_light": lightId,
        }),
      );
    } catch (e) {
      print("Set active light error: $e");
    }
  }
}
