import 'package:flutter/material.dart';
import 'dashboard_runners.dart';
import 'history_screen.dart';
import 'connecting_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _deviceConnected = false;
  bool _hasNewData = false; // 🔥 STATUS ADA DATA BARU DARI CHEST STRAP

  final GlobalKey<HistoryScreenState> _historyKey =
      GlobalKey<HistoryScreenState>();
  final GlobalKey<DashboardRunnersState> _dashboardKey =
      GlobalKey<DashboardRunnersState>();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Refresh history saat membuka tab history
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

  // 🔥 FUNGSI UNTUK RESET DASHBOARD SAAT DATA DIHAPUS
  void _onDataDeleted() {
    debugPrint("Data dihapus, refresh dashboard dan history");
    _dashboardKey.currentState?.resetData();
    _dashboardKey.currentState?.refreshLatestData();
    _historyKey.currentState?.refreshData();
    _historyKey.currentState?.resetData();

    // Reset status data baru
    setState(() {
      _hasNewData = false;
    });
  }

  // 🔥 FUNGSI UNTUK MENANDAI DATA SUDAH DI-DOWNLOAD
  void _onDataDownloaded() {
    debugPrint("Data sudah di-download, reset status hasNewData");
    setState(() {
      _hasNewData = false;
    });
    _refreshDashboard();
    _refreshHistory();
  }

  // 🔥 FUNGSI CEK DATA DARI CHEST STRAP (SIMULASI)
  // Nanti diganti dengan implementasi BLE sebenarnya
  Future<bool> _checkChestStrapData() async {
    // TODO: Ganti dengan panggilan ke BLE service
    // Contoh: return await BleService.hasNewData();

    // Simulasi: delay 500ms
    await Future.delayed(const Duration(milliseconds: 500));

    // 🔥 LOGIKA SEDERHANA:
    // - Jika chest strap memiliki data yang belum di-download, return true
    // - Jika tidak ada data, return false

    // Untuk simulasi, kita kembalikan false dulu
    // Nanti di implementasi sebenarnya, ini akan membaca dari chest strap
    return true;
  }

  // 🔥 FUNGSI UNTUK SYNC (TEKAN TOMBOL +)
  Future<void> _onSyncPressed() async {
    FocusScope.of(context).unfocus();

    // Buka halaman connecting
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectingScreen(
          onConnected: () {
            debugPrint("BLE Connected - Chest strap terhubung");
          },
          onCheckData: () async {
            // Cek apakah ada data baru dari chest strap
            bool hasData = await _checkChestStrapData();
            setState(() {
              _hasNewData = hasData;
            });
            debugPrint("Hasil cek data dari chest strap: $hasData");
            return hasData;
          },
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _deviceConnected = true;
      });
      _refreshDashboard();
      _refreshHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      DashboardRunners(
        key: _dashboardKey,
        onJumpToHistory: () => _onItemTapped(1),
        isConnectedFromMain: _deviceConnected,
        onDataSaved: _refreshHistory,
        hasNewDataFromBle: _hasNewData, // 🔥 KIRIM STATUS DATA KE DASHBOARD
      ),
      HistoryScreen(key: _historyKey),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(index: _selectedIndex, children: _pages),

      // 🔥 FLOATING ACTION BUTTON (TOMbol +)
      floatingActionButton: FloatingActionButton(
        onPressed: _onSyncPressed,
        backgroundColor: const Color(0xFFF77226),
        child: const Icon(Icons.add, size: 35, color: Colors.white),
        shape: const CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // BOTTOM NAVIGATION BAR
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
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
                // Tombol Beranda
                _buildNavItem(
                  Icons.home,
                  "Beranda",
                  _selectedIndex == 0,
                  () => _onItemTapped(0),
                ),

                // Spasi untuk FAB
                const SizedBox(width: 20),

                // Tombol History
                _buildNavItem(
                  Icons.history_rounded,
                  "History",
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

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
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
