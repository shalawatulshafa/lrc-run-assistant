import 'package:flutter/material.dart';

class SuccessScreen extends StatefulWidget {
  final bool hasNewData;
  final String? message; // 🔥 TAMBAHKAN - untuk pesan kustom (opsional)

  const SuccessScreen({
    super.key, 
    this.hasNewData = false,
    this.message,
  });

  @override
  _SuccessScreenState createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  @override
  void initState() {
    super.initState();
    // 🔥 TAMBAHKAN DELAY AGAR USER BISA MEMBACA PESAN
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pesan Utama
            Text(
              widget.message ?? "Koneksi Berhasil!",
              style: const TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Color(0xFFF77226),
              ),
            ),
            const SizedBox(height: 20),
            
            // Icon Sukses
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFF77226),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check, 
                color: Colors.white, 
                size: 60,
              ),
            ),
            const SizedBox(height: 30),
            
            // Status Data
            if (widget.hasNewData)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 10),
                    Text(
                      "Data lari tersedia!",
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Text(
                      "Tidak ada data baru",
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 30),
            
            // 🔥 TAMBAHKAN INDIKATOR LOADING ATAU COUNTDOWN (OPSIONAL)
            // CircularProgressIndicator(
            //   strokeWidth: 2,
            //   valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF77226)),
            // ),
          ],
        ),
      ),
    );
  }
}