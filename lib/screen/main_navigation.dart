import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // 🔥 IMPORT BARU

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
  BluetoothDevice? _connectedDevice; // 🔥 VARIABEL BARU

  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();
  final GlobalKey<DashboardRunnersState> _dashboardKey = GlobalKey<DashboardRunnersState>();

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
      return true; // Asumsikan ada data jika backend belum siap
    }
  }

  Future<void> _onSyncPressed() async {
    FocusScope.of(context).unfocus();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectingScreen(
          onConnected: () {
            setState(() {
              _deviceConnected = true;
            });
          },
          onCheckData: _checkChestStrapData,
        ),
      ),
    );

    // 🔥 TANGKAP DATA DARI SUCCESS SCREEN 🔥
    if (result is Map && result['connected'] == true) {
      setState(() {
        _deviceConnected = true;
        _hasNewData = result['hasNewData'] ?? true;
        _connectedDevice = result['device']; // Simpan perangkat
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardRunners(
            key: _dashboardKey,
            isConnectedFromMain: _deviceConnected,
            hasNewDataFromBle: _hasNewData, // 🔥 PASTIKAN INI MASUK
            connectedDevice: _connectedDevice, // 🔥 PASTIKAN INI MASUK
            onDataSaved: _refreshHistory,
            onJumpToHistory: () => _onItemTapped(1),
          ),
          HistoryScreen(key: _historyKey),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 30),
        height: 64,
        width: 64,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFF77226),
          elevation: 4,
          shape: const CircleBorder(),
          onPressed: _onSyncPressed,
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomAppBar(
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