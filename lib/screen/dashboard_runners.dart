import 'dart:async'; // 🔥 IMPORT BARU untuk mengatur Stream Baterai
import 'package:flutter/material.dart';

import '../models/run_session.dart';
import '../services/run_history_storage.dart';
import 'download_data_screen.dart';
import 'settings_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardRunners extends StatefulWidget {
  final VoidCallback? onJumpToHistory;
  final bool isConnectedFromMain;
  final BluetoothDevice? connectedDevice;
  final VoidCallback? onDataSaved;
  final bool hasNewDataFromBle;

  const DashboardRunners({
    super.key,
    this.onJumpToHistory,
    this.isConnectedFromMain = false,
    this.onDataSaved,
    this.hasNewDataFromBle = false,
    this.connectedDevice,
  });

  @override
  State<DashboardRunners> createState() => DashboardRunnersState();
}

class DashboardRunnersState extends State<DashboardRunners> {
  int batteryLevel = 0; // 🔥 Ubah default menjadi 0 (Nanti diupdate otomatis)
  RunSession? _latestRunData;
  bool _isLoadingLatest = true;
  bool _hasNewData = false;

  // 🔥 SUBSCRIPTION BATERAI
  StreamSubscription<List<int>>? _batterySubscription;

  @override
  void initState() {
    super.initState();
    _loadLatestRunData();
    _hasNewData = widget.hasNewDataFromBle;
    
    // 🔥 Jika saat pertama kali dibuka alat sudah konek, langsung baca baterai
    if (widget.isConnectedFromMain && widget.connectedDevice != null) {
      _initBatteryListener();
    }
  }

  @override
  void didUpdateWidget(DashboardRunners oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasNewDataFromBle != oldWidget.hasNewDataFromBle) {
      setState(() {
        _hasNewData = widget.hasNewDataFromBle;
      });
    }

    // 🔥 Jika perangkat baru saja terhubung (transisi dari false ke true)
    if (widget.isConnectedFromMain && !oldWidget.isConnectedFromMain && widget.connectedDevice != null) {
      _initBatteryListener();
    }
    
    // 🔥 Jika perangkat terputus, matikan listener
    if (!widget.isConnectedFromMain && oldWidget.isConnectedFromMain) {
      _cancelBatteryListener();
      setState(() => batteryLevel = 0);
    }
  }

  @override
  void dispose() {
    _cancelBatteryListener(); // 🔥 Hapus stream memory saat layar ditutup
    super.dispose();
  }

  // 🔥 FUNGSI UTAMA UNTUK MENDENGARKAN BATERAI
  Future<void> _initBatteryListener() async {
    try {
      final device = widget.connectedDevice!;
      
      // Minta perangkat untuk memberitahu layanan apa saja yang dia punya
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        // Cari UUID Baterai Standar (180F)
        if (service.uuid.toString().toUpperCase().contains("180F")) {
          for (var characteristic in service.characteristics) {
            // Cari Karakteristik Level Baterai (2A19)
            if (characteristic.uuid.toString().toUpperCase().contains("2A19")) {
              
              // Aktifkan Notifikasi Baterai
              await characteristic.setNotifyValue(true);

              // Dengarkan perubahan persentase (value[0] = 0-100)
              _batterySubscription = characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty && mounted) {
                  setState(() {
                    batteryLevel = value[0];
                  });
                }
              });
              
              // Coba baca secara manual sekali saat pertama kali init
              List<int> initialValue = await characteristic.read();
              if (initialValue.isNotEmpty && mounted) {
                setState(() {
                  batteryLevel = initialValue[0];
                });
              }
              break; 
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal mendengarkan status baterai: $e");
    }
  }

  void _cancelBatteryListener() {
    _batterySubscription?.cancel();
    _batterySubscription = null;
  }

  Future<void> _loadLatestRunData() async {
    setState(() {
      _isLoadingLatest = true;
    });

    try {
      final List<RunSession> runs = await RunHistoryStorage.getRuns();

      setState(() {
        _latestRunData = runs.isNotEmpty ? runs.first : null;
        _isLoadingLatest = false;
      });
    } catch (e) {
      debugPrint('Error loading latest data: $e');
      setState(() {
        _isLoadingLatest = false;
      });
    }
  }

  void refreshLatestData() {
    _loadLatestRunData();
  }

  void resetData() {
    setState(() {
      _latestRunData = null;
      _isLoadingLatest = false;
    });
  }

  void markDataDownloaded() {
    setState(() {
      _hasNewData = false;
    });
    refreshLatestData();
    widget.onDataSaved?.call();
  }

  bool get canDownload => widget.isConnectedFromMain && _hasNewData;

  @override
  Widget build(BuildContext context) {
    final bool isConnected = widget.isConnectedFromMain;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        toolbarHeight: 60,
        title: const Padding(
          padding: EdgeInsets.only(left: 24, top: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat Pagi,',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color.fromARGB(255, 165, 165, 165),
                ),
              ),
              Text(
                'Runners',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color.fromARGB(255, 165, 165, 165),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      onDataDeleted: () {
                        resetData();
                        refreshLatestData();
                        widget.onDataSaved?.call();
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.settings,
                color: Color(0xFFF77226),
                size: 30,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLatestRunData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  image: const DecorationImage(
                    image: AssetImage('assets/images/runners_bg.jpg'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Color.fromARGB(48, 0, 0, 0),
                      BlendMode.darken,
                    ),
                  ),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'Sudah olahraga\nhari ini?',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected
                      ? (_hasNewData ? Colors.green.shade50 : Colors.blue.shade50)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected
                        ? (_hasNewData ? Colors.green.shade200 : Colors.blue.shade200)
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isConnected
                          ? (_hasNewData ? Icons.check_circle : Icons.info_outline)
                          : Icons.bluetooth_disabled,
                      color: isConnected ? (_hasNewData ? Colors.green : Colors.blue) : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isConnected
                            ? (_hasNewData
                                ? 'Data lari siap diunduh!'
                                : 'Tidak ada data baru. Silakan lari dulu.')
                            : 'Chest strap tidak terhubung. Klik tombol +',
                        style: TextStyle(
                          fontSize: 12,
                          color: isConnected
                              ? (_hasNewData ? Colors.green.shade800 : Colors.blue.shade800)
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canDownload
                      ? () async {
                          final prefs = await SharedPreferences.getInstance();
                          final String jwtToken = prefs.getString('authToken') ?? '';

                          if (jwtToken.isEmpty) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sesi login tidak valid, harap login ulang.')),
                            );
                            return;
                          }

                          if (widget.connectedDevice == null) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Perangkat tidak ditemukan.')),
                            );
                            return;
                          }

                          if (!context.mounted) return;

                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DownloadDataScreen(
                                onDataDownloaded: markDataDownloaded,
                                connectedDevice: widget.connectedDevice!, 
                                jwtToken: jwtToken,                       
                                targetPattern: "3:2",                     
                              ),
                            ),
                          );

                          if (result == true) {
                            await _loadLatestRunData();
                            widget.onDataSaved?.call();
                          }
                        }
                      : null,
                  icon: Icon(
                    Icons.download,
                    color: canDownload ? Colors.black87 : Colors.grey,
                  ),
                  label: Text(
                    !isConnected
                        ? 'Koneksi tidak tersedia'
                        : (!_hasNewData ? 'Tidak ada data baru' : 'Unduh Data Lari'),
                    style: TextStyle(
                      color: canDownload ? Colors.black87 : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canDownload ? const Color(0xFFF77226) : Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Latest Run Data',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (_latestRunData != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _formatDate(_latestRunData!.date),
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        OutlinedButton(
                          onPressed: () {
                            widget.onJumpToHistory?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF77226)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'History',
                            style: TextStyle(color: Color(0xFFF77226)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (_isLoadingLatest)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_latestRunData == null)
                      Column(
                        children: [
                          const SizedBox(height: 10),
                          Center(
                            child: Icon(
                              Icons.fitness_center,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Center(
                            child: Text(
                              'Belum ada data lari',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'Klik tombol Unduh Data Lari',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatBox(
                                  Icons.timer,
                                  'Duration',
                                  _latestRunData!.duration,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatBox(
                                  Icons.location_on,
                                  'Distance',
                                  _latestRunData!.distanceLabel,
                                  suffix: 'km',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatBox(
                                  Icons.show_chart,
                                  'Avg SPM',
                                  '${_latestRunData!.avgSpm}',
                                  suffix: 'steps/min',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatBox(
                                  Icons.percent,
                                  'Kepatuhan',
                                  '${_latestRunData!.compliance}%',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusCard(
                      _buildBatteryIcon(isConnected ? batteryLevel : 0),
                      'Baterai Chest Strap',
                      isConnected ? '$batteryLevel%' : '-',
                      Colors.black,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatusCard(
                      Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        size: 30,
                        color: isConnected ? Colors.blue : Colors.black,
                      ),
                      'Status Koneksi',
                      isConnected ? 'Connected' : 'Not Connected',
                      isConnected ? Colors.blue : const Color(0xFF8B0000),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final DateTime localTime = dateTime.toLocal(); // 🔥 Ikutkan zona waktu lokal HP
    return '${localTime.day} ${_getMonthName(localTime.month)} ${localTime.year}, ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return months[month - 1];
  }

  Widget _buildStatBox(
    IconData icon,
    String title,
    String value, {
    String suffix = '',
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFF77226), size: 16),
              const SizedBox(width: 5),
              Text(
                title,
                style: const TextStyle(color: Color(0xFFF77226), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: ' $suffix',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    Widget iconWidget,
    String title,
    String value,
    Color valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          iconWidget,
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIcon(int percentage) {
    return Container(
      width: 45,
      height: 22,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          if (percentage > 0)
            Container(
              width: (percentage / 100) * 40,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: percentage > 20 ? Colors.black : Colors.red,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          Positioned(
            right: -2,
            top: 4,
            child: Container(
              width: 3,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}