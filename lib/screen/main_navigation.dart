import 'package:flutter/material.dart';
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
      return true;
    }
  }

  Future<void> _onSyncPressed() async {
    FocusScope.of(context).unfocus();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectingScreen(
          onConnected: () {
            debugPrint('BLE Connected - Chest strap terhubung');
          },
          onCheckData: () async {
            final bool hasData = await _checkChestStrapData();
            setState(() {
              _hasNewData = hasData;
            });
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
    final List<Widget> pages = [
      DashboardRunners(
        key: _dashboardKey,
        onJumpToHistory: () => _onItemTapped(1),
        isConnectedFromMain: _deviceConnected,
        onDataSaved: _refreshHistory,
        hasNewDataFromBle: _hasNewData,
      ),
      HistoryScreen(key: _historyKey),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: _onSyncPressed,
        backgroundColor: const Color(0xFFF77226),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 35, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
