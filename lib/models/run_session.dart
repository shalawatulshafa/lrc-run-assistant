import 'dart:convert';

class RunSession {
  final String id;
  final String title;
  final DateTime date;
  final double distance;
  final int avgSpm;
  final int compliance;
  final String duration;

  const RunSession({
    required this.id,
    required this.title,
    required this.date,
    required this.distance,
    required this.avgSpm,
    required this.compliance,
    required this.duration,
  });

  factory RunSession.fromJson(Map<String, dynamic> json) {
    final dynamic rawDate = json['date'] ?? json['dateTime'];
    DateTime parsedDate;
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    }

    final dynamic rawDistance = json['distance'];
    final dynamic rawAvgSpm = json['avgSpm'];
    final dynamic rawCompliance = json['compliance'];
    final dynamic rawDuration = json['duration'];

    String formattedDuration;
    if (rawDuration is num) {
      formattedDuration = _secondsToDuration(rawDuration.toInt());
    } else {
      formattedDuration = rawDuration?.toString() ?? '00:00';
    }

    return RunSession(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Sesi Lari',
      date: parsedDate,
      distance: rawDistance is num
          ? rawDistance.toDouble()
          : double.tryParse(rawDistance?.toString() ?? '') ?? 0,
      avgSpm: rawAvgSpm is num ? rawAvgSpm.toInt() : int.tryParse(rawAvgSpm?.toString() ?? '') ?? 0,
      compliance: rawCompliance is num
          ? rawCompliance.toInt()
          : int.tryParse(rawCompliance?.toString() ?? '') ?? 0,
      duration: formattedDuration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'distance': distance,
      'avgSpm': avgSpm,
      'compliance': compliance,
      'duration': duration,
    };
  }

  RunSession copyWith({
    String? id,
    String? title,
    DateTime? date,
    double? distance,
    int? avgSpm,
    int? compliance,
    String? duration,
  }) {
    return RunSession(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      distance: distance ?? this.distance,
      avgSpm: avgSpm ?? this.avgSpm,
      compliance: compliance ?? this.compliance,
      duration: duration ?? this.duration,
    );
  }

  String get distanceLabel {
    final bool isWholeNumber = distance == distance.truncateToDouble();
    return isWholeNumber ? distance.toStringAsFixed(0) : distance.toStringAsFixed(1);
  }

  int get durationSeconds {
    final String trimmed = duration.trim();
    if (trimmed.contains(':')) {
      final List<String> parts = trimmed.split(':');
      if (parts.length == 2) {
        final int minutes = int.tryParse(parts[0]) ?? 0;
        final int seconds = int.tryParse(parts[1]) ?? 0;
        return (minutes * 60) + seconds;
      }
      if (parts.length == 3) {
        final int hours = int.tryParse(parts[0]) ?? 0;
        final int minutes = int.tryParse(parts[1]) ?? 0;
        final int seconds = int.tryParse(parts[2]) ?? 0;
        return (hours * 3600) + (minutes * 60) + seconds;
      }
    }
    return int.tryParse(trimmed) ?? 0;
  }

  static String _secondsToDuration(int totalSeconds) {
    final int safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
    final int minutes = safeSeconds ~/ 60;
    final int seconds = safeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static List<RunSession> decodeStringList(List<String> rawData) {
    final List<RunSession> result = [];
    for (final String item in rawData) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(item);
        result.add(RunSession.fromJson(jsonMap));
      } catch (_) {
        // Skip malformed entries to keep UI resilient.
      }
    }
    return result;
  }

  static List<String> encodeStringList(List<RunSession> runs) {
    return runs.map((run) => jsonEncode(run.toJson())).toList();
  }
}
