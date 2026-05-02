import 'package:shared_preferences/shared_preferences.dart';

import '../models/run_session.dart';
import 'api_service.dart';

class RunHistoryStorage {
  static const String _runHistoryKey = 'runHistory';
  static const String _tokenKey = 'authToken';

  static Future<String?> _getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<List<RunSession>> _getCachedRuns() async {
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
      return _getCachedRuns();
    }

    try {
      final List<dynamic> remote = await ApiService.getRunHistory(token);
      final List<RunSession> runs = remote
          .whereType<Map<String, dynamic>>()
          .map(RunSession.fromJson)
          .toList();
      await saveRuns(runs);
      return runs;
    } catch (_) {
      return _getCachedRuns();
    }
  }

  static Future<RunSession?> addRun(RunSession run) async {
    final String? token = await _getToken();
    if (token == null || token.isEmpty) {
      final List<RunSession> existing = await _getCachedRuns();
      existing.add(run);
      await saveRuns(existing);
      return run;
    }

    try {
      final Map<String, dynamic> syncResult = await ApiService.syncRunData(token, {
        'dateTime': run.date.toIso8601String(),
        'distance': run.distance,
        'avgSpm': run.avgSpm,
        'compliance': run.compliance,
        'duration': run.durationSeconds,
      });

      final String? runId = syncResult['runId']?.toString();
      if (runId == null || runId.isEmpty) {
        await getRuns();
        return null;
      }

      final Map<String, dynamic> detail = await ApiService.getRunDetail(token, runId);
      final RunSession created = RunSession.fromJson(detail);

      final List<RunSession> existing = await _getCachedRuns();
      final List<RunSession> updated = existing.where((item) => item.id != created.id).toList()..add(created);
      await saveRuns(updated);
      return created;
    } catch (_) {
      final List<RunSession> existing = await _getCachedRuns();
      existing.add(run);
      await saveRuns(existing);
      return run;
    }
  }

  static Future<RunSession?> getRunById(String id) async {
    final String? token = await _getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final Map<String, dynamic> detail = await ApiService.getRunDetail(token, id);
        return RunSession.fromJson(detail);
      } catch (_) {
        // fallback to cache
      }
    }

    final List<RunSession> runs = await _getCachedRuns();
    for (final RunSession run in runs) {
      if (run.id == id) return run;
    }
    return null;
  }

  static Future<void> updateRunTitle(String id, String newTitle) async {
    final List<RunSession> runs = await _getCachedRuns();
    final List<RunSession> updated = runs
        .map((run) => run.id == id ? run.copyWith(title: newTitle) : run)
        .toList();
    await saveRuns(updated);
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_runHistoryKey);
  }
}
