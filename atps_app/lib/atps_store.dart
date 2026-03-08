import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'traffic_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AtpsStore {
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
      Future<void> fetchRegisteredUnits() async {
  try {
    final response = await http.get(
      Uri.parse("http://172.30.30.79:5000/api/units"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      registeredUnits.value = List<Map<String, dynamic>>.from(data);
    }
  } catch (e) {
    print("Error fetching units: $e");
  }
}        

  // =========================
  // DRIVER STATE
  // =========================

  final status = signal("RED");
  final isLoading = signal(false);
  final unitId = signal("AMB-042");
  final eta = signal("8:45");

  // =========================
  // ADMIN STATE
  // =========================

  // Inside your AtpsStore class in lib/atps_store.dart

final emergencyRequests = signal<List<Map<String, dynamic>>>([
  {
    "id": "1",
    "unit": "KANIV-108 (KL-07-BZ-4210)",
    "location": "Vyttila Hub ➔ Medical Trust Hospital",
    "status": "PENDING",
    "eta": "2 min",
  },
  {
    "id": "2",
    "unit": "AMB-P12 (Private)",
    "location": "MG Road ➔ Aster Medcity",
    "status": "APPROVED",
    "eta": "5 min",
  },
  {
    "id": "3",
    "unit": "FIRE-09 (KL-07-AL)",
    "location": "Marine Drive ➔ Ernakulam Market",
    "status": "COMPLETED",
    "eta": "12 min",
  },
]);

final trafficSignals = listSignal<Map<String, dynamic>>([
  {"id": "S1", "name": "Vyttila Junction", "status": "RED", "online": true},
  {"id": "S2", "name": "Kaloor Stadium Jn", "status": "GREEN", "online": true},
  {"id": "S3", "name": "Edappally Toll", "status": "RED", "online": true},
  {"id": "S4", "name": "Palarivattom Jn", "status": "RED", "online": false},
]);

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


  late final pendingRequestsCount = computed(
      () => emergencyRequests.value.where((r) => r['status'] == 'PENDING').length);

  // =========================
  // TRAFFIC ACTIONS
  // =========================

  Future<void> requestPriority() async {
    if (status.value == "GREEN") return;

    isLoading.value = true;
    await _api.requestGreen(unitId.value);
    status.value = "GREEN";
    isLoading.value = false;
  }

  Future<void> reset() async {
    isLoading.value = true;
    await _api.resetSignal();
    status.value = "RED";
    isLoading.value = false;
  }

  // --- ACTIONS: ADMIN ---
void approveRequest(String requestId) {
  // Finds the request in our Kochi list and updates status
  final currentRequests = List<Map<String, dynamic>>.from(emergencyRequests.value);
  final index = currentRequests.indexWhere((req) => req['id'] == requestId);
  
  if (index != -1) {
    currentRequests[index]['status'] = 'APPROVED';
    emergencyRequests.value = currentRequests; // This triggers the UI refresh
    print("Approved request for: ${currentRequests[index]['unit']}");
  }
}

void denyRequest(String requestId) {
  final currentRequests = List<Map<String, dynamic>>.from(emergencyRequests.value);
  final index = currentRequests.indexWhere((req) => req['id'] == requestId);
  
  if (index != -1) {
    currentRequests[index]['status'] = 'DENIED';
    emergencyRequests.value = currentRequests; // This triggers the UI refresh
  }
}

void toggleSignalManual(String id) {
  final index = trafficSignals.value
      .indexWhere((element) => element['id'] == id);

  if (index != -1) {
    var sig =
        Map<String, dynamic>.from(trafficSignals.value[index]);

    sig['status'] =
        sig['status'] == 'RED' ? 'GREEN' : 'RED';

    trafficSignals.value[index] = sig;
    
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

}
