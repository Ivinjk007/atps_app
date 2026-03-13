import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // REQUIRED FOR kIsWeb
import 'package:http/http.dart' as http;

class TrafficService {
  // ================= CONFIG =================
  static const bool useRealServer = true;

  //SMART URL SELECTOR 
  static String get serverUrl {
    if (kIsWeb) {
      // 1. If running on Chrome (Web) on your computer
      return "http://127.0.0.1:5000/api";
    } else {
      // 2. If running on a Physical Phone or Android Emulator
      // Put your computer's EXACT IPv4 address here. 
      return "http://172.30.30.79:5000/api"; 
    }
  }

  // ================= LOGIN =================
  Future<Map<String, dynamic>> login(
      String username,
      String password,
      String role) async {

    if (!useRealServer) {
      await Future.delayed(const Duration(seconds: 2));
      return {"success": true};
    }

    try {
      final response = await http.post(
        Uri.parse("$serverUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
          "role": role,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        return {
          "success": false,
          "message": data["message"] ?? "Login failed"
        };
      }

    } catch (e) {
      return {
        "success": false,
        "message": "Cannot connect to server"
      };
    }
  }

  // ================= SIGNUP =================
   Future<Map<String, dynamic>> signup(
  String name,
  String username,
  String password,
  String unitId,
  String phone,
  String role,
) async {

  if (!useRealServer) {
    await Future.delayed(const Duration(seconds: 2));
    return {"success": true};
  }

  try {
    final response = await http.post(
      Uri.parse("$serverUrl/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "username": username,
        "password": password,
        "unit_id": unitId,
        "phone": phone,     // ADDED
        "role": role,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data;
    } else {
      return {
        "success": false,
        "message": data["message"] ?? "Signup failed"
      };
    }

  } catch (e) {
    return {
      "success": false,
      "message": "Connection Failed"
    };
  }
}

  // ================= TRAFFIC METHODS =================
  Future<void> requestGreen(String unitId) async {
    await Future.delayed(const Duration(seconds: 2));
  }

  Future<void> resetSignal() async {
    await Future.delayed(const Duration(seconds: 1));
  }
}