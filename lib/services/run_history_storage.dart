import 'package:shared_preferences/shared_preferences.dart';

import '../models/run_session.dart';

class RunHistoryStorage {
  static const String _runHistoryKey = 'runHistory';

  static Future<List<RunSession>> getRuns() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_runHistoryKey) ?? [];
    return RunSession.decodeStringList(raw);
  }

  static Future<void> saveRuns(List<RunSession> runs) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_runHistoryKey, RunSession.encodeStringList(runs));
  }

  static Future<void> addRun(RunSession run) async {
    final List<RunSession> existing = await getRuns();
    existing.add(run);
    await saveRuns(existing);
  }

  static Future<RunSession?> getRunById(String id) async {
    final List<RunSession> runs = await getRuns();
    for (final RunSession run in runs) {
      if (run.id == id) return run;
    }
    return null;
  }

  static Future<void> updateRunTitle(String id, String newTitle) async {
    final List<RunSession> runs = await getRuns();
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
