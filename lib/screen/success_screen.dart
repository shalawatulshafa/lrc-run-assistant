import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SuccessScreen extends StatefulWidget {
  final bool hasNewData;
  final String? message;
  final BluetoothDevice? connectedDevice;

  const SuccessScreen({
    super.key, 
    this.hasNewData = false,
    this.message,
    this.connectedDevice,
  });

  @override
  _SuccessScreenState createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // 🔥 Mengembalikan Map berisi data koneksi lengkap
        Navigator.pop(context, {
          'connected': true,
          'hasNewData': widget.hasNewData,
          'device': widget.connectedDevice,
        });
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
            // 🔥 FITUR BARU: Menambahkan Icon Checklist / Centang
            const Icon(
              Icons.check_circle,
              color: Color(0xFFF77226),
              size: 80, // Ukuran icon diperbesar agar terlihat jelas sebagai success screen
            ),
            const SizedBox(height: 20),
            
            // Teks Status Koneksi
            Text(
              widget.message ?? "Koneksi Berhasil!",
              style: const TextStyle(
                fontSize: 22, // Ukuran sedikit diperbesar agar lebih proporsional dengan icon
                fontWeight: FontWeight.bold,
                color: Color(0xFFF77226),
              ),
            ),
            
            // Blok "Tidak ada data baru" / "Data lari tersedia!" telah dihapus secara total
          ],
        ),
      ),
    );
  }
}