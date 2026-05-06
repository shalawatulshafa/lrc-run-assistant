import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/run_session.dart';
import '../services/run_history_storage.dart';
import '../services/run_sync_service.dart'; // Pastikan file service ini sudah Anda buat
import 'detail_lari_screen.dart';

class DownloadDataScreen extends StatefulWidget {
  final VoidCallback? onDataDownloaded;
  
  // 🔥 INI 3 VARIABEL BARU YANG DIMINTA OLEH ERROR TADI
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
      final String id = serverResponse['data']['runId'];
      final summary = serverResponse['data']['summary'];
      
      final RunSession newSession = RunSession(
        id: id,
        title: 'Lari LRC ${widget.targetPattern}',
        date: DateTime.now(),
        distance: 0.0, // Isi 0 karena belum ada perhitungan jarak
        avgSpm: summary['avgSpm'],
        compliance: summary['compliance'],
        duration: summary['formattedDuration'], // "MM:SS" dari backend Node.js
      );

      // 3. Simpan ke SQLite HP
      final RunSession savedSession = await RunHistoryStorage.addRun(newSession) ?? newSession;
      
      // Beritahu Dashboard bahwa data baru sudah masuk
      widget.onDataDownloaded?.call();

      if (!mounted) return;

      // 4. Tutup layar loading, buka layar hasil lari
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