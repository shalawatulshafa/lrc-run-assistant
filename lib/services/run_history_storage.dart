import 'package:shared_preferences/shared_preferences.dart';

import '../models/run_session.dart';
import 'api_service.dart';
import 'dart:convert';

class RunHistoryStorage {
  static const String _runHistoryKey = 'runHistory';
  static const String _tokenKey = 'authToken';

  static Future<String?> _getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // 🔥 1. UBAH MENJADI PUBLIC: getLocalRuns agar bisa dipanggil instan tanpa API
  static Future<List<RunSession>> getLocalRuns() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_runHistoryKey) ?? [];
    return RunSession.decodeStringList(raw);
  }

  static Future<void> saveRuns(List<RunSession> runs) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_runHistoryKey, RunSession.encodeStringList(runs));
  }

  static Future<List<RunSession>> getRuns() async {
    final String? token = await _getToken();
    if (token == null || token.isEmpty) {
      return getLocalRuns();
    }

    try {
      final List<dynamic> remote = await ApiService.getRunHistory(token);
      final List<RunSession> runs = remote
          .whereType<Map<String, dynamic>>()
          .map(RunSession.fromJson)
          .toList();
      
      // Simpan backup lokal setelah berhasil fetch dari server
      await saveRuns(runs);
      return runs;
    } catch (_) {
      // Jika gagal/offline, kembalikan data lokal
      return getLocalRuns();
    }
  }

  // 🔥 PERBAIKAN: addRun sekarang difokuskan untuk penyimpanan lokal.
  // (Sinkronisasi API dari ESP32 ditangani oleh RunSyncService -> ApiService.syncRun)
  static Future<RunSession?> addRun(RunSession run) async {
    try {
      final List<RunSession> existing = await getLocalRuns();
      existing.add(run);
      await saveRuns(existing);
      return run;
    } catch (e) {
      print('Gagal menyimpan data lari ke lokal: $e');
      return null;
    }
  }

  static Future<void> updateRun(RunSession updatedRun) async {
    // 🔥 Menggunakan getLocalRuns() agar data lokal tidak ditimpa server saat diedit
    List<RunSession> currentRuns = await getLocalRuns();
    
    int index = currentRuns.indexWhere((run) => run.id == updatedRun.id);
    if (index != -1) {
      currentRuns[index] = updatedRun;
      await saveRuns(currentRuns);
    }
  }

  static Future<RunSession?> getRunById(String id) async {
    final String? token = await _getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final Map<String, dynamic> detail = await ApiService.getRunDetail(token, id);
        return RunSession.fromJson(detail);
      } catch (_) {
        // Jika gagal API, lanjut cari di lokal
      }
    }

    final List<RunSession> runs = await getLocalRuns();
    for (final RunSession run in runs) {
      if (run.id == id) return run;
    }
    return null;
  }

  static Future<void> updateRunTitle(String id, String newTitle) async {
    // 🔥 Menggunakan getLocalRuns()
    final List<RunSession> runs = await getLocalRuns();
    final List<RunSession> updated = runs
        .map((run) => run.id == id ? run.copyWith(title: newTitle) : run)
        .toList();
    await saveRuns(updated);
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_runHistoryKey);
  }

  // 🔥 TAMBAHAN: Fungsi untuk menghapus 1 data spesifik di penyimpanan lokal
  static Future<void> deleteRunLocal(String id) async {
    final List<RunSession> runs = await getLocalRuns();
    runs.removeWhere((run) => run.id == id);
    await saveRuns(runs);
  }
}