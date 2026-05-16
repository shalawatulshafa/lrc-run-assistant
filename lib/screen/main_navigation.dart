import 'dart:async'; // 🔥 IMPORT BARU untuk StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 

import 'dashboard_runners.dart';
import 'history_screen.dart';
import 'connecting_screen.dart';
import '../services/api_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _deviceConnected = false;
  bool _hasNewData = false;
  BluetoothDevice? _connectedDevice; 
  
  // 🔥 VARIABEL BARU: Untuk menyimpan "Pendengar" status Bluetooth
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();
  final GlobalKey<DashboardRunnersState> _dashboardKey = GlobalKey<DashboardRunnersState>();

  @override
  void dispose() {
    _connectionSubscription?.cancel(); // Bersihkan memori saat aplikasi ditutup
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      _historyKey.currentState?.refreshData();
    }
  }

  void _refreshHistory() {
    _historyKey.currentState?.refreshData();
  }

  void _refreshDashboard() {
    _dashboardKey.currentState?.refreshLatestData();
  }

  Future<bool> _checkChestStrapData() async {
    try {
      return await ApiService.hasNewData();
    } catch (_) {
      return true; 
    }
  }

  // 🔥 FITUR BARU: Memantau status koneksi secara Real-Time
  void _listenToConnection(BluetoothDevice device) {
    _connectionSubscription?.cancel(); // Batalkan listener lama jika ada
    
    // Dengarkan perubahan dari alat. Jika alat mati, state berubah otomatis!
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        print("ESP32 Terputus atau Mati!");
        if (mounted) {
          setState(() {
            _deviceConnected = false;
            _connectedDevice = null;
          });
        }
      }
    });
  }

  Future<void> _onSyncPressed() async {
    // 🔥 FITUR BARU: Jika sudah connect, tombol berfungsi untuk DISCONNECT MANUAL
    if (_deviceConnected && _connectedDevice != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Putus Koneksi"),
          content: const Text("Apakah Anda yakin ingin memutuskan koneksi dari alat ESP32?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Tutup dialog
                await _connectedDevice!.disconnect(); // Putus koneksi bluetooth
                // Catatan: Kita tidak perlu setState(false) di sini karena 
                // fungsi _listenToConnection di atas akan otomatis mendeteksinya!
              },
              child: const Text("Putus Koneksi", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return; // Hentikan fungsi agar tidak membuka ConnectingScreen
    }

    // Jika belum connect, buka layar ConnectingScreen (Scan)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConnectingScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      if (result['connected'] == true) {
        setState(() {
          _deviceConnected = true;
          _connectedDevice = result['device'];
          _hasNewData = true; 
        });
        
        // 🔥 Mulai pantau perangkat yang baru terhubung
        if (_connectedDevice != null) {
          _listenToConnection(_connectedDevice!);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardRunners(
            key: _dashboardKey,
            onJumpToHistory: () => _onItemTapped(1),
            isConnectedFromMain: _deviceConnected,
            connectedDevice: _connectedDevice,
            hasNewDataFromBle: _hasNewData,
            onDataSaved: () {
              setState(() {
                _hasNewData = false;
              });
              _refreshHistory();
            },
            // 🔥 Menerima update dari Dashboard jika koneksi putus
            onConnectionChanged: (isConnected) {
              setState(() {
                _deviceConnected = isConnected;
                if (!isConnected) {
                  _connectedDevice = null;
                }
              });
            },
          ),
          HistoryScreen(key: _historyKey),
        ],
      ),
      
      // 🔥 PERUBAHAN UI: Tombol '+' Berubah Dinamis!
      floatingActionButton: FloatingActionButton(
        onPressed: _onSyncPressed,
        // Jika connect, warna jadi Merah. Jika tidak, warna Oranye.
        backgroundColor: _deviceConnected ? Colors.red : const Color(0xFFF77226),
        child: Icon(
          // Jika connect, ikon jadi 'Bluetooth Silang'. Jika tidak, ikon '+'
          _deviceConnected ? Icons.bluetooth_disabled : Icons.add,
          color: Colors.white,
        ),
        shape: const CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        elevation: 0,
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                Icons.home,
                'Beranda',
                _selectedIndex == 0,
                () => _onItemTapped(0),
              ),
              const SizedBox(width: 20),
              _buildNavItem(
                Icons.history_rounded,
                'History',
                _selectedIndex == 1,
                () => _onItemTapped(1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFFF77226) : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFF77226) : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}