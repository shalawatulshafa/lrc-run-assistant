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
  final String targetPattern;

  const DownloadDataScreen({
    super.key, 
    this.onDataDownloaded,
    required this.connectedDevice,
    required this.jwtToken,
    required this.targetPattern,
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

  Future<void> _startRealDownload() async {
    try {
      setState(() {
        _statusText = 'Mengunduh data lari dari perangkat...';
      });

      // 1. Panggil Service Sinkronisasi (Menyedot data dari ESP32)
      final serverResponse = await RunSyncService().startSync(
        widget.connectedDevice, 
        widget.targetPattern, 
        widget.jwtToken
      );

      if (!mounted) return;

      setState(() {
        _progress = 1.0;
        _statusText = 'Sinkronisasi Selesai!';
      });

      // Beri jeda agar tulisan 100% / Selesai terlihat oleh user
      await Future.delayed(const Duration(milliseconds: 500));

      // 2. Ambil data hasil analitik dari Node.js
      final String id = (serverResponse['runId'] ?? '').toString();
      final dynamic summary = serverResponse['summary'] ?? {};

      // Konversi graphData dari backend ke List<double>
      List<double> parsedGraphData = [];
      if (summary['graphData'] != null && summary['graphData'] is List) {
        parsedGraphData = (summary['graphData'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
      }

      // 3. Buat Object RunSession Baru (Tanpa Distance)
      final RunSession newSession = RunSession(
        id: id,
        title: 'Sesi Lari LRC', // Judul default, bisa diubah user nanti
        date: DateTime.now(),
        // distance: 0.0, // 🔥 BARIS INI DIHAPUS
        targetPattern: widget.targetPattern, // 🔥 DITAMBAHKAN: Menyimpan pola yang dikirim
        avgLrc: (summary['avgLrc'] ?? "-").toString(),
        avgSpm: ((summary['avgSpm'] ?? 0) as num).toInt(),
        compliance: ((summary['compliance'] ?? 0) as num).toInt(),
        duration: (summary['duration'] ?? "00:00").toString(),
        rawLrcData: parsedGraphData, // 🔥 DITAMBAHKAN: Agar grafik langsung muncul di DetailLariScreen
      );

      // 4. Simpan ke Cache Lokal HP
      final RunSession savedSession = await RunHistoryStorage.addRun(newSession) ?? newSession;
      
      // Beritahu Dashboard bahwa data baru sudah masuk
      widget.onDataDownloaded?.call();

      if (!mounted) return;

      // 5. Tutup layar loading, buka layar detail lari
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DetailLariScreen(
            runSession: savedSession,
            onDataUpdated: () {},
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progress = 0.0;
        _statusText = 'Pengunduhan Gagal. Silakan coba lagi.';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          // Hanya izinkan back jika error (0.0) atau selesai (1.0)
          onPressed: (_progress == 1.0 || _progress == 0.0) 
              ? () => Navigator.pop(context, false) 
              : null,
        ),
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
                  const SizedBox(height: 15),
                  if (_progress != null)
                    Text(
                      '${(_progress! * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD6885D),
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