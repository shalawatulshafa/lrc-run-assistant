// lib/services/api_service.dart
// 🔥 FILE INI AKAN DIISI OLEH BACKEND DEVELOPER
// 🔥 INI HANYA TEMPLATE, JANGAN DIUBAH ISI NYA SAMPAI BACKEND JADI

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 🔥 GANTI URL INI SAAT BACKEND SUDAH JADI
  static const String baseUrl = "https://api.lrc-run.com/v1";

  // ============================================================
  // 🔥 AUTHENTICATION ENDPOINTS
  // ============================================================

  /// Login user
  /// Request: { "email": "string", "password": "string" }
  /// Response: { "success": true, "data": { "token": "string", "user": {...} } }
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    // TODO: Backend akan implementasi
    throw UnimplementedError();
  }

  /// Register user baru
  /// Request: { "email": "string", "name": "string", "password": "string" }
  /// Response: { "success": true, "data": { "token": "string", "user": {...} } }
  static Future<Map<String, dynamic>> register(
    String email,
    String name,
    String password,
  ) async {
    // TODO: Backend akan implementasi
    throw UnimplementedError();
  }

  /// Logout user
  /// Headers: Authorization: Bearer {token}
  static Future<void> logout(String token) async {
    // TODO: Backend akan implementasi
    throw UnimplementedError();
  }

  // ============================================================
  // 🔥 USER PROFILE ENDPOINTS
  // ============================================================

  /// Get user profile
  /// Headers: Authorization: Bearer {token}
  /// Response: { "success": true, "data": { "id": "string", "name": "string", "email": "string" } }
  static Future<Map<String, dynamic>> getProfile(String token) async {
    // TODO: Backend akan implementasi
    throw UnimplementedError();
  }

  /// Update user profile
  /// Headers: Authorization: Bearer {token}
  /// Request: { "name": "string", "email": "string" }
  /// Response: { "success": true, "data": { ... } }
  static Future<Map<String, dynamic>> updateProfile(
    String token,
    String name,
    String email,
  ) async {
    // TODO: Backend akan implementasi
    throw UnimplementedError();
  }

  // ============================================================
  // 🔥 RUN DATA ENDPOINTS
  // ============================================================

  /// Get all run history
  /// Headers: Authorization: Bearer {token}
  /// Response: { "success": true, "data": [ { "id": "string", "title": "string", ... } ] }
  static Future<List<dynamic>> getRunHistory(String token) async {
    // TODO: Backend akan implementasi
    throw UnimplementedError();
  }

  /// Get detail run by ID
  /// Headers: Authorization: Bearer {token}
  /// Response: { "success": true, "data": { ... } }
  static Future<Map<String, dynamic>> getRunDetail(
    String token,
    String runId,
  ) async {
    // TODO: Backend akan implementasi
    throw UnimplementedError();
  }

  /// Sync run data from chest strap
  /// Headers: Authorization: Bearer {token}
  /// Request: { "dateTime": "string", "distance": 0, "avgSpm": 0, "compliance": 0, "duration": 0 }
  /// Response: { "success": true, "data": { "runId": "string", "title": "string" } }
  static Future<Map<String, dynamic>> syncRunData(
    String token,
    Map<String, dynamic> runData,
  ) async {
    // TODO: Backend akan implementasi
    throw UnimplementedError();
  }

  /// Delete run data by ID
  /// Headers: Authorization: Bearer {token}
  static Future<void> deleteRunData(String token, String runId) async {
    // TODO: Backend akan implementasi
    throw UnimplementedError();
  }

  // ============================================================
  // 🔥 CHEST STRAP (BLE) ENDPOINTS
  // ============================================================

  /// Check if chest strap has new data
  /// Response: { "hasNewData": true/false, "dataCount": 0 }
  static Future<bool> hasNewData() async {
    // TODO: Backend akan implementasi (BLE)
    throw UnimplementedError();
  }

  /// Get chest strap status
  /// Response: { "connected": true/false, "batteryLevel": 0, "mode": "string" }
  static Future<Map<String, dynamic>> getChestStrapStatus() async {
    // TODO: Backend akan implementasi (BLE)
    throw UnimplementedError();
  }

  /// Download run data from chest strap
  /// Response: { "success": true, "data": [ ... ] }
  static Future<List<Map<String, dynamic>>> downloadRunData() async {
    // TODO: Backend akan implementasi (BLE)
    throw UnimplementedError();
  }
}
