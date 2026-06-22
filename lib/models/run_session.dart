import 'dart:convert';

// 🔥 KELAS BARU: Untuk menyimpan titik grafik + warna polanya
class LrcPoint {
  final double y;
  final String pattern;
  // Pola yang sebenarnya terdeteksi di cycle ini (mis. "3:2", "2:2", "5:3").
  // Berbeda dari `pattern` yang merupakan TARGET pattern user.
  // Nullable untuk backward compat dengan data lari lama.
  final String? actualPattern;

  const LrcPoint({
    required this.y,
    required this.pattern,
    this.actualPattern,
  });

  factory LrcPoint.fromJson(Map<String, dynamic> json) {
    return LrcPoint(
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      pattern: json['pattern']?.toString() ?? "3:2",
      actualPattern: json['actualPattern']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'y': y,
    'pattern': pattern,
    'actualPattern': actualPattern,
  };
}

class RunSession {
  final String id;
  final String title;
  final DateTime date;
  final int? sessionNumber;
  final String targetPattern;
  final String avgLrc;
  final int avgSpm;
  final int compliance;
  final String duration;
  final List<LrcPoint> rawLrcData;
  // Distribusi pola dari SEMUA siklus (basis sama dengan compliance),
  // dipakai histogram. Berbeda dari rawLrcData yang sudah terfilter
  // outlier sumbu-Y untuk keperluan chart garis. Null untuk sesi lama
  // sebelum field ini ditambahkan di backend.
  final Map<String, int>? patternDistribution;
  final String? rawCsv;
  // Metrik baru dari format CSV step-anchored (null untuk data lari lama)
  final double? avgLag;
  final double? phaseDrift;
  final int? consistencyScore;

  const RunSession({
    required this.id,
    required this.title,
    required this.date,
    this.sessionNumber,
    required this.targetPattern,
    required this.avgLrc,
    required this.avgSpm,
    required this.compliance,
    required this.duration,
    this.rawLrcData = const [],
    this.patternDistribution,
    this.rawCsv,
    this.avgLag,
    this.phaseDrift,
    this.consistencyScore,
  });

  // 🔥 PERBAIKAN: Menambahkan fungsi copyWith untuk edit judul dll
  RunSession copyWith({
    String? id,
    String? title,
    DateTime? date,
    int? sessionNumber,
    String? targetPattern,
    String? avgLrc,
    int? avgSpm,
    int? compliance,
    String? duration,
    List<LrcPoint>? rawLrcData,
    Map<String, int>? patternDistribution,
    String? rawCsv,
    double? avgLag,
    double? phaseDrift,
    int? consistencyScore,
  }) {
    return RunSession(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      targetPattern: targetPattern ?? this.targetPattern,
      avgLrc: avgLrc ?? this.avgLrc,
      avgSpm: avgSpm ?? this.avgSpm,
      compliance: compliance ?? this.compliance,
      duration: duration ?? this.duration,
      rawLrcData: rawLrcData ?? this.rawLrcData,
      patternDistribution: patternDistribution ?? this.patternDistribution,
      rawCsv: rawCsv ?? this.rawCsv,
      avgLag: avgLag ?? this.avgLag,
      phaseDrift: phaseDrift ?? this.phaseDrift,
      consistencyScore: consistencyScore ?? this.consistencyScore,
    );
  }

  // Helper untuk memecah String JSON avgLrc menjadi Map
  Map<String, String> get parsedAvgLrc {
    try {
      if (avgLrc.startsWith('{')) {
        final Map<String, dynamic> decoded = jsonDecode(avgLrc);
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (_) {
      // Abaikan jika error parsing
    }
    return { targetPattern: avgLrc };
  }

  factory RunSession.fromJson(Map<String, dynamic> json) {
    final dynamic rawDate = json['date'] ?? json['dateTime'];
    DateTime parsedDate;
    
    if (rawDate is DateTime) {
      parsedDate = rawDate.toLocal();
    } else {
      parsedDate = (DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now()).toLocal();
    }

    List<LrcPoint> parsedGraphData = [];
    if (json['rawLrcData'] != null && json['rawLrcData'] is List) {
      parsedGraphData = (json['rawLrcData'] as List).map((e) {
        if (e is num) {
          return LrcPoint(y: e.toDouble(), pattern: json['targetPattern']?.toString() ?? "3:2");
        } else if (e is Map) {
          return LrcPoint.fromJson(Map<String, dynamic>.from(e));
        }
        return const LrcPoint(y: 0.0, pattern: "3:2");
      }).toList();
    }

    Map<String, int>? parsedPatternDistribution;
    if (json['patternDistribution'] != null && json['patternDistribution'] is Map) {
      parsedPatternDistribution = (json['patternDistribution'] as Map).map(
        (key, value) => MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0),
      );
    }

    return RunSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Lari LRC',
      date: parsedDate,
      sessionNumber: json['sessionNumber'] != null ? int.tryParse(json['sessionNumber'].toString()) : null,
      targetPattern: json['targetPattern']?.toString() ?? '-',
      avgLrc: json['avgLrc']?.toString() ?? '0.0 : 0.0',
      avgSpm: int.tryParse(json['avgSpm']?.toString() ?? '0') ?? 0,
      compliance: int.tryParse(json['compliance']?.toString() ?? '0') ?? 0,
      duration: json['duration']?.toString() ?? '00:00',
      rawLrcData: parsedGraphData,
      patternDistribution: parsedPatternDistribution,
      rawCsv: json['rawCsv']?.toString(),
      avgLag: json['avgLag'] != null ? double.tryParse(json['avgLag'].toString()) : null,
      phaseDrift: json['phaseDrift'] != null ? double.tryParse(json['phaseDrift'].toString()) : null,
      consistencyScore: json['consistencyScore'] != null ? int.tryParse(json['consistencyScore'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'sessionNumber': sessionNumber,
      'targetPattern': targetPattern,
      'avgLrc': avgLrc,
      'avgSpm': avgSpm,
      'compliance': compliance,
      'duration': duration,
      'rawLrcData': rawLrcData.map((e) => e.toJson()).toList(),
      'patternDistribution': patternDistribution,
      'rawCsv': rawCsv,
      'avgLag': avgLag,
      'phaseDrift': phaseDrift,
      'consistencyScore': consistencyScore,
    };
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

  static List<RunSession> decodeStringList(List<String> rawData) {
    final List<RunSession> result = [];
    for (final String item in rawData) {
      try {
        final Map<String, dynamic> map = jsonDecode(item);
        result.add(RunSession.fromJson(map));
      } catch (e) {
        // Abaikan
      }
    }
    return result;
  }

  static List<String> encodeStringList(List<RunSession> sessions) {
    return sessions.map((e) => jsonEncode(e.toJson())).toList();
  }
}