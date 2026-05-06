import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  // For Android emulator, use: http://10.0.2.2:3000/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.8.100.153:3000/v1',
  );

  static Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Exception _toException(http.Response response) {
    try {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final dynamic error = body['error'];
      final String message =
          error is Map<String, dynamic> ? (error['message']?.toString() ?? 'Request failed') : 'Request failed';
      return Exception(message);
    } catch (_) {
      return Exception('Request failed with status ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> _parseData(http.Response response) async {
    final Map<String, dynamic> decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded['success'] == true) {
      final dynamic data = decoded['data'];
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    }
    throw _toException(response);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseData(response);
  }

  static Future<Map<String, dynamic>> register(String email, String name, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'name': name, 'password': password}),
    );
    return _parseData(response);
  }

  static Future<void> logout(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: _headers(token: token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toException(response);
    }
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/profile'),
      headers: _headers(token: token),
    );
    return _parseData(response);
  }

  static Future<Map<String, dynamic>> updateProfile(String token, String name, String email) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user/profile'),
      headers: _headers(token: token),
      body: jsonEncode({'name': name, 'email': email}),
    );
    return _parseData(response);
  }

  static Future<List<dynamic>> getRunHistory(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/runs'),
      headers: _headers(token: token),
    );
    final Map<String, dynamic> decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded['success'] == true) {
      final dynamic data = decoded['data'];
      return data is List ? data : <dynamic>[];
    }
    throw _toException(response);
  }

  static Future<Map<String, dynamic>> getRunDetail(String token, String runId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/run/$runId'),
      headers: _headers(token: token),
    );
    return _parseData(response);
  }

  static Future<Map<String, dynamic>> syncRunData(String token, Map<String, dynamic> runData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/runs/sync'),
      headers: _headers(token: token),
      body: jsonEncode(runData),
    );
    return _parseData(response);
  }

  static Future<void> deleteRunData(String token, String runId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/runs/$runId'),
      headers: _headers(token: token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toException(response);
    }
  }

  static Future<bool> hasNewData() async {
    // Backend BLE endpoint is not implemented yet.
    return true;
  }

  static Future<Map<String, dynamic>> getChestStrapStatus() async {
    // Backend BLE endpoint is not implemented yet.
    return {'connected': true, 'batteryLevel': 85, 'mode': 'SYNC'};
  }

  static Future<List<Map<String, dynamic>>> downloadRunData() async {
    // Backend BLE endpoint is not implemented yet.
    return <Map<String, dynamic>>[];
  }
}
