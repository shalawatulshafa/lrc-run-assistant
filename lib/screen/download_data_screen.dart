import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'detail_lari_screen.dart';

class DownloadDataScreen extends StatefulWidget {
  final VoidCallback? onDataDownloaded;
  const DownloadDataScreen({super.key, this.onDataDownloaded});

  @override
  _DownloadDataScreenState createState() => _DownloadDataScreenState();
}

class _DownloadDataScreenState extends State<DownloadDataScreen> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() async {
    // Simulasi progress
    for (int i = 0; i <= 100; i++) {
      if (!mounted) return;
      await Future.delayed(Duration(milliseconds: 50));
      setState(() {
        _progress = i / 100;
      });
    }

    if (mounted) {
      // Data dari chest strap
      final now = DateTime.now();
      final runData = {
        'dateTime': now,
        'distance': 5.2,
        'avgSpm': 164,
        'compliance': 80,
        'duration': '42:15',
      };
      
      // Generate judul sederhana
      String autoTitle = "Lari ${runData['distance']}km - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      
      // Simpan data ke SharedPreferences
      await _saveRunData(autoTitle, runData);
      
      if (widget.onDataDownloaded != null) {
        widget.onDataDownloaded!();
      }
      
      // 🔥 LANGSUNG NAVIGASI KE DETAIL LARI (bukan pop ke beranda)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DetailLariScreen(
              runData: runData,
              runTitle: autoTitle,
              onDataUpdated: (){

              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveRunData(String title, Map<String, dynamic> runData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? existingData = prefs.getStringList('runHistory') ?? [];
    
    String id = DateTime.now().millisecondsSinceEpoch.toString();
    
    Map<String, dynamic> newRun = {
      'id': id,
      'title': title,
      'date': (runData['dateTime'] as DateTime).toIso8601String(),
      'distance': runData['distance'],
      'avgSpm': runData['avgSpm'],
      'compliance': runData['compliance'],
      'duration': runData['duration'],
    };
    
    existingData.add(jsonEncode(newRun));
    await prefs.setStringList('runHistory', existingData);
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
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: _progress == 1.0 ? () => Navigator.pop(context, false) : null,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _progress < 1.0 
                ? "Pengunduhan masih berjalan,\nharap tunggu" 
                : "Pengunduhan Selesai!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 100),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD6885D)),
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    "${(_progress * 100).toInt()}%",
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD6885D)
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 100),
            // 🔥 HAPUS TOMBOL "Kembali ke Beranda" karena akan otomatis pindah ke detail
            // if (_progress == 1.0)
            //   ElevatedButton(
            //     onPressed: () => Navigator.pop(context, true),
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: Color(0xFFD6885D),
            //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
            //     ),
            //     child: Text("Kembali ke Beranda", style: TextStyle(color: Colors.white)),
            //   ),
          ],
        ),
      ),
    );
  }
}