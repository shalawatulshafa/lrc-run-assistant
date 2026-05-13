import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

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

  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  bool _isScanning = false;
  bool _isConnecting = false; // Menandakan user sedang mencoba connect ke 1 perangkat

  @override
  void initState() {
    super.initState();
    // Animasi Loading (Hanya dipakai saat _isConnecting = true)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Mulai otomatis scan saat layar dibuka
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

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

      // Mulai scan selama 10 detik
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (mounted) {
          setState(() {
            // Filter hanya perangkat yang punya nama agar list tidak penuh dengan device acak
            _scanResults = results.where((r) => 
              r.device.platformName.isNotEmpty || r.device.advName.isNotEmpty
            ).toList();
          });
        }
      });

      // Tunggu sampai scan selesai
      await Future.delayed(const Duration(seconds: 10));

    } catch (e) {
      print("Error scanning: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  // Fungsi yang dipanggil saat user menekan salah satu perangkat di list
  Future<void> _connectToDevice(BluetoothDevice device) async {
    // Hentikan scan jika masih berjalan
    FlutterBluePlus.stopScan();
    
    setState(() {
      _isConnecting = true; // Munculkan layar loading oranye
    });

    try {
      // Coba hubungkan
      await device.connect(timeout: const Duration(seconds: 5));
      
      bool hasData = false;
      if (widget.onCheckData != null) {
        hasData = await widget.onCheckData!(); 
      }

      widget.onConnected?.call();

      if (!mounted) return;

      // Masuk ke Success Screen
      final resultData = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SuccessScreen(
            hasNewData: hasData,
            connectedDevice: device, 
          ),
        ),
      );

      if (!mounted) return;
      // Estafetkan data kembali ke Beranda
      Navigator.pop(context, resultData); 

    } catch (e) {
      print("Gagal Connect: $e");
      if (!mounted) return;
      
      // Jika gagal, masuk ke Failed Screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FailedScreen(
            message: "Gagal terhubung: ${e.toString().replaceAll('Exception: ', '')}", 
          ),
        ), 
      );
      
      if (!mounted) return;
      // Kembalikan ke list agar user bisa coba lagi (tidak langsung ke beranda)
      setState(() {
        _isConnecting = false; 
      });
      
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanSubscription?.cancel(); 
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isConnecting ? 'Menghubungkan...' : 'Pilih Perangkat',
          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            FlutterBluePlus.stopScan(); 
            Navigator.pop(context);
          },
        ),
        actions: [
          // Tombol refresh manual (Hanya muncul jika tidak sedang connecting)
          if (!_isConnecting)
            IconButton(
              icon: _isScanning 
                  ? const SizedBox(
                      width: 20, height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)
                    )
                  : const Icon(Icons.refresh, color: Colors.black),
              onPressed: _isScanning ? null : _startScan,
            )
        ],
      ),
      body: _isConnecting 
          ? _buildLoadingView() 
          : _buildDeviceList(),
    );
  }

  // Tampilan 1: Daftar Perangkat (Mode Manual)
  Widget _buildDeviceList() {
    if (_scanResults.isEmpty && !_isScanning) {
      return const Center(
        child: Text(
          "Tidak ada perangkat Bluetooth ditemukan.\nPastikan ESP32 menyala dan dekat.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final r = _scanResults[index];
        final deviceName = r.device.platformName.isNotEmpty ? r.device.platformName : r.device.advName;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFF77226),
              child: Icon(Icons.bluetooth, color: Colors.white),
            ),
            title: Text(
              deviceName.isNotEmpty ? deviceName : 'Unknown Device',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(r.device.remoteId.toString(), style: const TextStyle(fontSize: 12)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF77226),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => _connectToDevice(r.device),
              child: const Text('Hubungkan', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        );
      },
    );
  }

  // Tampilan 2: Animasi Loading (Mode Connecting)
  Widget _buildLoadingView() {
    return Center(
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
          const SizedBox(height: 20),
          const Text(
            "...Connecting...",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}