// lib/services/mock_api.dart
// 🔥 PAKAI FILE INI SEMENTARA UNTUK TESTING TANPA BACKEND
// 🔥 NANTI DIGANTI DENGAN API SERVICE ASLI

import 'dart:convert';

class MockApiService {
  static List<Map<String, dynamic>> _mockRuns = [];
  static String _mockToken = "";

  // ============================================================
  // 🔥 MOCK DATA DEFAULT (untuk testing tampilan)
  // ============================================================

  static void initMockData() {
    if (_mockRuns.isEmpty) {
      _mockRuns = [
        {
          'id': '1',
          'title': 'Pagi 5.2km - Lari Rutin',
          'date': DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
          'distance': 5.2,
          'avgSpm': 164,
          'compliance': 80,
          'duration': 2535,
        },
        {
          'id': '2',
          'title': 'Sore 3.1km - Interval Training',
          'date': DateTime.now()
              .subtract(const Duration(days: 5))
              .toIso8601String(),
          'distance': 3.1,
          'avgSpm': 178,
          'compliance': 92,
          'duration': 1875,
        },
      ];
    }
  }

  // ============================================================
  // 🔥 AUTHENTICATION
  // ============================================================

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    if (email.isEmpty || password.isEmpty) {
      return {'success': false, 'message': 'Email dan password harus diisi'};
    }

    _mockToken = "mock_token_${DateTime.now().millisecondsSinceEpoch}";

    return {
      'success': true,
      'data': {
        'token': _mockToken,
        'user': {'id': '1', 'name': email.split('@')[0], 'email': email},
      },
    };
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String name,
    String password,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    _mockToken = "mock_token_${DateTime.now().millisecondsSinceEpoch}";

    return {
      'success': true,
      'data': {
        'token': _mockToken,
        'user': {'id': '1', 'name': name, 'email': email},
      },
    };
  }

  static Future<void> logout(String token) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockToken = "";
  }

  // ============================================================
  // 🔥 USER PROFILE
  // ============================================================

  static Future<Map<String, dynamic>> getProfile(String token) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'success': true,
      'data': {'id': '1', 'name': 'Runners', 'email': 'runner@example.com'},
    };
  }

  static Future<Map<String, dynamic>> updateProfile(
    String token,
    String name,
    String email,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'success': true,
      'data': {'id': '1', 'name': name, 'email': email},
    };
  }

  // ============================================================
  // 🔥 RUN DATA
  // ============================================================

  static Future<List<dynamic>> getRunHistory(String token) async {
    await Future.delayed(const Duration(milliseconds: 500));
    initMockData();
    return _mockRuns;
  }

  static Future<Map<String, dynamic>> getRunDetail(
    String token,
    String runId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    var run = _mockRuns.firstWhere((r) => r['id'] == runId, orElse: () => {});
    return {'success': true, 'data': run};
  }

  static Future<Map<String, dynamic>> syncRunData(
    String token,
    Map<String, dynamic> runData,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    String id = DateTime.now().millisecondsSinceEpoch.toString();
    String title = "Lari ${runData['distance']}km";

    Map<String, dynamic> newRun = {
      'id': id,
      'title': title,
      'date': DateTime.now().toIso8601String(),
      'distance': runData['distance'],
      'avgSpm': runData['avgSpm'],
      'compliance': runData['compliance'],
      'duration': runData['duration'],
    };

    _mockRuns.insert(0, newRun);

    return {
      'success': true,
      'data': {'runId': id, 'title': title},
    };
  }

  static Future<void> deleteRunData(String token, String runId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockRuns.removeWhere((r) => r['id'] == runId);
  }

  // ============================================================
  // 🔥 CHEST STRAP (BLE)
  // ============================================================

  static Future<bool> hasNewData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Simulasi: kadang ada data, kadang tidak
    return DateTime.now().second % 3 == 0;
  }

  static Future<Map<String, dynamic>> getChestStrapStatus() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {'connected': true, 'batteryLevel': 85, 'mode': 'SYNC'};
  }

  static Future<List<Map<String, dynamic>>> downloadRunData() async {
    await Future.delayed(const Duration(seconds: 2));
    return [
      {
        'dateTime': DateTime.now(),
        'distance': 5.2,
        'avgSpm': 164,
        'compliance': 80,
        'duration': 2535,
      },
    ];
  }
}
