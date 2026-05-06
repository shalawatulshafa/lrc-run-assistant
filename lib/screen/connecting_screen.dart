import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // Import Baru
import 'dart:async';
import 'dart:io'; // Import Baru untuk mengecek OS Android

import 'success_screen.dart';
import 'failed_screen.dart'; 

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

  BluetoothDevice? _foundDevice; 
  StreamSubscription<List<ScanResult>>? _scanSubscription;

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

    _startRealBluetoothConnection();
  }

  Future<void> _startRealBluetoothConnection() async {
    try {
      if (Platform.isAndroid) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        if (statuses[Permission.bluetoothScan] != PermissionStatus.granted ||
            statuses[Permission.bluetoothConnect] != PermissionStatus.granted) {
          throw Exception("Izin Bluetooth ditolak oleh pengguna.");
        }
      }

      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        throw Exception("Bluetooth mati");
      }

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName == "LRC-Tracker-ESP32" || r.device.advName == "LRC-Tracker-ESP32") {
            _foundDevice = r.device;
            FlutterBluePlus.stopScan(); 
            break;
          }
        }
      });

      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 500));
        return FlutterBluePlus.isScanningNow && _foundDevice == null;
      });

      if (_foundDevice != null) {
        await _foundDevice!.connect(timeout: const Duration(seconds: 5));
        
        // Panggil API untuk memastikan ada data (Saat ini di-mocking true)
        bool hasData = false;
        if (widget.onCheckData != null) {
          hasData = await widget.onCheckData!(); 
        }

        widget.onConnected?.call();

        if (!mounted) return;

        // 🔥 PERUBAHAN UTAMA DI SINI 🔥
        // Kita tunggu SuccessScreen selesai dan ambil hasil Map-nya
        final resultData = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              hasNewData: hasData,
              connectedDevice: _foundDevice, 
            ),
          ),
        );

        if (!mounted) return;
        // Lempar (estafet) data Map tersebut kembali ke MainNavigation
        Navigator.pop(context, resultData); 

      } else {
        throw Exception("Perangkat ESP32 tidak ditemukan. Pastikan alat menyala.");
      }

    } catch (e) {
      print("Gagal Connect: $e");
      if (!mounted) return;
      
      // 🔥 PERUBAHAN DI SINI JUGA (Untuk layar gagal) 🔥
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FailedScreen(
            message: "Gagal terhubung: ${e.toString().replaceAll('Exception: ', '')}", 
          ),
        ), 
      );
      
      if (!mounted) return;
      Navigator.pop(context, null); // Kembali ke Beranda dengan nilai null
      
    } finally {
      _scanSubscription?.cancel();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanSubscription?.cancel(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            FlutterBluePlus.stopScan(); 
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
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