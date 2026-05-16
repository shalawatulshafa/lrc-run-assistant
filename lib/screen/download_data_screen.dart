import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/run_session.dart';
import '../services/run_history_storage.dart';
import '../services/run_sync_service.dart'; 
import 'detail_lari_screen.dart';

class DownloadDataScreen extends StatefulWidget {
  final VoidCallback? onDataDownloaded;
  
  final BluetoothDevice connectedDevice;
  final String jwtToken;
  
  // 🔥 PERBAIKAN: targetPattern dihapus karena sekarang diurus otomatis oleh Backend

  const DownloadDataScreen({
    super.key, 
    this.onDataDownloaded,
    required this.connectedDevice,
    required this.jwtToken,
  });

  @override
  State<DownloadDataScreen> createState() => _DownloadDataScreenState();
}

class _DownloadDataScreenState extends State<DownloadDataScreen> {
  double? _progress; // Dibuat null agar bar loading bergerak bolak-balik (indeterminate)
  String _statusText = 'Menghubungkan ke sensor...';

  @override
  void initState() {
    super.initState();
    _startRealDownload();
  }

  // Fungsi khusus untuk menerjemahkan tanggal "14/05/2026, 15.29.48" di Flutter
  DateTime _parseCustomDate(String dateString) {
    try {
      if (dateString.isEmpty) return DateTime.now();
      final parts = dateString.split(', ');
      if (parts.length != 2) return DateTime.tryParse(dateString) ?? DateTime.now();
      
      final dateParts = parts[0].split('/');
      final timeParts = parts[1].split('.');
      
      return DateTime(
        int.parse(dateParts[2]), // Tahun
        int.parse(dateParts[1]), // Bulan
        int.parse(dateParts[0]), // Tanggal
        int.parse(timeParts[0]), // Jam
        int.parse(timeParts[1]), // Menit
        int.parse(timeParts[2]), // Detik
      );
    } catch (e) {
      return DateTime.now();
    }
  }

  Future<void> _startRealDownload() async {
    try {
      setState(() {
        _statusText = 'Mengunduh data lari dari perangkat...';
      });

      // 1. Panggil Service Sinkronisasi (Sekarang hanya butuh device & token)
      final RunSyncService syncService = RunSyncService();
      final Map<String, dynamic> serverResponse = await syncService.startSync(
        widget.connectedDevice,
        widget.jwtToken,
      );

      setState(() {
        _statusText = 'Menyimpan riwayat lari...';
      });

      // 2. Tangkap Array 'runs' dari Backend
      final List<dynamic> runsData = serverResponse['runs'] ?? [];
      if (runsData.isEmpty) {
        throw Exception("Tidak ada sesi lari valid yang berhasil diproses.");
      }

      RunSession? latestSession;

      // 3. Simpan setiap sesi ke dalam Memori HP
      for (var runItem in runsData) {
        final summary = runItem['summary'];
        final String runId = runItem['runId'].toString();

        final RunSession newSession = RunSession(
          id: runId,
          title: 'Lari LRC Sesi ${summary['sessionNumber'] ?? ''}'.trim(),
          date: _parseCustomDate(summary['startDate']?.toString() ?? ''),
          sessionNumber: (summary['sessionNumber'] as num?)?.toInt(),
          targetPattern: summary['targetPattern']?.toString() ?? '3:2',
          avgLrc: summary['avgLrc']?.toString() ?? '-',
          avgSpm: (summary['avgSpm'] as num?)?.toInt() ?? 0,
          compliance: (summary['compliance'] as num?)?.toInt() ?? 0,
          duration: summary['duration']?.toString() ?? '00:00',
          // Parsing array grafik
          rawLrcData: (summary['graphData'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
        );

        // Simpan ke SharedPreferences
        await RunHistoryStorage.saveRun(newSession);
        
        // Terus timpa agar mendapatkan sesi yang paling terakhir diproses
        latestSession = newSession; 
      }

      setState(() {
        _statusText = 'Selesai!';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (widget.onDataDownloaded != null) {
        widget.onDataDownloaded!();
      }

      if (!mounted) return;

      // 4. Navigasi ke Detail Layar menggunakan Sesi Terakhir (terbaru)
      if (latestSession != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DetailLariScreen(runSession: latestSession!),
          ),
        );
      } else {
        Navigator.pop(context); // Kembali jika entah kenapa gagal
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Gagal: ${e.toString()}';
      });

      // Kembali ke layar sebelumnya setelah 3 detik jika gagal
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Unduh Data', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress, 
                      minHeight: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD6885D)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}