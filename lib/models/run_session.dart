import 'dart:convert';

class RunSession {
  final String id;
  final String title;
  final DateTime date;
  final int? sessionNumber; // 🔥 TAMBAHAN BARU: Menyimpan urutan sesi
  final String targetPattern;
  final String avgLrc;
  final int avgSpm;
  final int compliance;
  final String duration;
  final List<double> rawLrcData; 

  const RunSession({
    required this.id,
    required this.title,
    required this.date,
    this.sessionNumber, // 🔥 Opsional tapi penting
    required this.targetPattern,
    required this.avgLrc,
    required this.avgSpm,
    required this.compliance,
    required this.duration,
    this.rawLrcData = const [],
  });

  factory RunSession.fromJson(Map<String, dynamic> json) {
    final dynamic rawDate = json['date'] ?? json['dateTime'];
    DateTime parsedDate;
    
    // Konversi waktu ke zona waktu HP (WIB / UTC+7)
    if (rawDate is DateTime) {
      parsedDate = rawDate.toLocal();
    } else {
      parsedDate = (DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now()).toLocal();
    }

    // Parsing data grafik dari backend agar aman menjadi List<double>
    List<double> parsedGraphData = [];
    if (json['rawLrcData'] != null && json['rawLrcData'] is List) {
      parsedGraphData = (json['rawLrcData'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    final dynamic rawDuration = json['duration'];
    String formattedDuration;
    if (rawDuration is num) {
      formattedDuration = _secondsToDuration(rawDuration.toInt());
    } else {
      formattedDuration = rawDuration?.toString() ?? '00:00';
    }

    return RunSession(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Sesi Lari',
      date: parsedDate,
      sessionNumber: json['sessionNumber'] != null ? (json['sessionNumber'] as num).toInt() : null, // 🔥 Ambil dari JSON
      targetPattern: json['targetPattern']?.toString() ?? '3:2',
      avgLrc: json['avgLrc']?.toString() ?? '-',
      avgSpm: (json['avgSpm'] ?? 0).toInt(),
      compliance: (json['compliance'] ?? 0).toInt(),
      duration: formattedDuration,
      rawLrcData: parsedGraphData, 
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'sessionNumber': sessionNumber, // 🔥 Pastikan tersimpan ke memori lokal
    'targetPattern': targetPattern,
    'avgLrc': avgLrc,
    'avgSpm': avgSpm,
    'compliance': compliance,
    'duration': duration,
    'rawLrcData': rawLrcData, // 🔥 Simpan grafik ke memori lokal
  };

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
    List<double>? rawLrcData,
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
    );
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
      } catch (e) {
        // Abaikan data yang corrupt
      }
    }
    return result;
  }

  static List<String> encodeToStringList(List<RunSession> sessions) {
    return sessions.map((s) => jsonEncode(s.toJson())).toList();
  }
}