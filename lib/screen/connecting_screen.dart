import 'package:flutter/material.dart';
import 'success_screen.dart';
import 'failed_screen.dart'; // 🔥 TAMBAHKAN IMPORT FAILED SCREEN

class ConnectingScreen extends StatefulWidget {
  final VoidCallback? onConnected;
  final Future<bool> Function()? onCheckData;

  const ConnectingScreen({
    super.key,
    this.onConnected,
    this.onCheckData,
  });

  @override
  _ConnectingScreenState createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hasNewData = false;
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _connectAndCheckData();
  }

  Future<void> _connectAndCheckData() async {
    try {
      // Simulasi koneksi BLE (4 detik)
      await Future.delayed(const Duration(seconds: 4));
      
      // 🔥 SIMULASI SUKSES/GAGAL KONEK
      // Ganti nilai ini untuk testing
      bool connectionSuccess = true; // true = sukses, false = gagal
      
      if (!connectionSuccess && mounted) {
        // 🔥 TAMPILKAN FAILED SCREEN
        final retry = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FailedScreen(
              message: "Koneksi Gagal",
              subtitle: "Pastikan chest strap dalam mode SYNC\natau baterai perangkat cukup",
              onRetry: () {
                Navigator.pop(context, true);
              },
            ),
          ),
        );
        
        if (retry == true) {
          // Ulangi koneksi
          _connectAndCheckData();
          return;
        } else {
          if (mounted) Navigator.pop(context, false);
          return;
        }
      }
      
      // Jika sukses konek
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        
        // Panggil callback jika ada
        if (widget.onConnected != null) {
          widget.onConnected!();
        }
        
        // Cek apakah ada data baru dari chest strap
        bool hasData = false;
        if (widget.onCheckData != null) {
          hasData = await widget.onCheckData!();
          setState(() {
            _hasNewData = hasData;
          });
        }
        
        // Navigasi ke success screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              hasNewData: _hasNewData,
            ),
          ),
        );
        
        if (result == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      // 🔥 HANDLE ERROR
      if (mounted) {
        final retry = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FailedScreen(
              message: "Koneksi Gagal",
              subtitle: "Terjadi kesalahan: ${e.toString().substring(0, 50)}...",
              onRetry: () => Navigator.pop(context, true),
            ),
          ),
        );
        
        if (retry == true) {
          _connectAndCheckData();
        } else {
          Navigator.pop(context, false);
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Menghubungkan ke Chest Strap...",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Pastikan chest strap dalam mode SYNC",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 250,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: (1.0 - (_controller.value)).clamp(0.0, 1.0),
                        child: Container(
                          width: 150 * _animation.value,
                          height: 70 * _animation.value,
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 255, 152, 93),
                            borderRadius: BorderRadius.all(Radius.elliptical(150, 70)),
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 150,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 255, 152, 93),
                      borderRadius: BorderRadius.all(Radius.elliptical(150, 70)),
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              "...Connecting...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}