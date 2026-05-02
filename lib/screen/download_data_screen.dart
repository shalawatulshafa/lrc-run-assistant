import 'package:flutter/material.dart';

import '../models/run_session.dart';
import '../services/run_history_storage.dart';
import 'detail_lari_screen.dart';

class DownloadDataScreen extends StatefulWidget {
  final VoidCallback? onDataDownloaded;

  const DownloadDataScreen({super.key, this.onDataDownloaded});

  @override
  State<DownloadDataScreen> createState() => _DownloadDataScreenState();
}

class _DownloadDataScreenState extends State<DownloadDataScreen> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    for (int i = 0; i <= 100; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {
        _progress = i / 100;
      });
    }

    if (!mounted) return;

    final DateTime now = DateTime.now();
    final String id = now.millisecondsSinceEpoch.toString();
    final String autoTitle =
        'Lari 5.2km - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final RunSession draftSession = RunSession(
      id: id,
      title: autoTitle,
      date: now,
      distance: 5.2,
      avgSpm: 164,
      compliance: 80,
      duration: '42:15',
    );

    final RunSession savedSession = await RunHistoryStorage.addRun(draftSession) ?? draftSession;
    widget.onDataDownloaded?.call();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DetailLariScreen(
          runSession: savedSession,
          onDataUpdated: () {},
        ),
      ),
    );
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
          onPressed: _progress == 1.0 ? () => Navigator.pop(context, false) : null,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _progress < 1.0 ? 'Pengunduhan masih berjalan,\nharap tunggu' : 'Pengunduhan Selesai!',
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
                  Text(
                    '${(_progress * 100).toInt()}%',
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
