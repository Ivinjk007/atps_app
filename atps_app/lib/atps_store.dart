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
          "lat": sig["lat"],
          "lon": sig["lon"],
          "battery_level": sig["battery_level"] ?? 100,
          "last_updated": sig["last_updated"],
          // Set online to true if recently updated. We can default it to true for now since ESP32 will ping
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

  Future<void> requestPriority(String fromLocation, String toLocation) async {
    if (status.value == "GREEN") return;

    isLoading.value = true;
    final res = await _api.requestGreen(unitId.value, driverName.value, fromLocation, toLocation, driverPhone.value);
    
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

  Future<void> reset() async {
    isLoading.value = true;
    await _api.resetSignal(unitId.value);

    // Auto-remove from active emergencies locally
    final currentRequests = List<Map<String, dynamic>>.from(emergencyRequests.value);
    for (var req in currentRequests) {
      if (req['unit'] == unitId.value && req['status'] == 'APPROVED') {
        req['status'] = 'COMPLETED';
        _api.updateRequestStatus(req['id'], 'COMPLETED');
      }
    }
    emergencyRequests.value = currentRequests;

    status.value = "RED";
    isLoading.value = false;
  }

  // --- ACTIONS: ADMIN ---

void denyRequest(String requestId) {
  final currentRequests = List<Map<String, dynamic>>.from(emergencyRequests.value);
  final index = currentRequests.indexWhere((req) => req['id'] == requestId);
  
  if (index != -1) {
    currentRequests[index]['status'] = 'COMPLETED';
    _api.updateRequestStatus(requestId, 'COMPLETED');
    emergencyRequests.value = currentRequests; // This triggers the UI refresh
  }
}

Future<void> toggleSignalManual(String junctionId) async {
  try {
    final index = trafficSignals.value
        .indexWhere((element) => element['id'] == junctionId);

    if (index == -1) return;

    var sig = Map<String, dynamic>.from(trafficSignals.value[index]);

    String newColor = sig['status'] == 'RED' ? 'GREEN' : 'RED';

    // Update UI immediately
    sig['status'] = newColor;
    trafficSignals.value[index] = sig;

    // Send command to Flask backend
    await http.post(
      Uri.parse("${TrafficService.serverUrl}/admin/signal_override"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "junction_id": junctionId,
        "desired_color": newColor
      }),
    );

  } catch (e) {
    print("Signal override error: $e");
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
}
