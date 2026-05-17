import 'dart:async'; 
import 'package:flutter/material.dart';
import 'dart:convert';
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
  final Function(bool)? onConnectionChanged; 

  const DashboardRunners({
    super.key,
    this.onJumpToHistory,
    this.isConnectedFromMain = false,
    this.onDataSaved,
    this.hasNewDataFromBle = false,
    this.connectedDevice,
    this.onConnectionChanged, 
  });

  @override
  State<DashboardRunners> createState() => DashboardRunnersState();
}

class DashboardRunnersState extends State<DashboardRunners> {
  int batteryLevel = 0; 
  RunSession? _latestRunData;
  bool _isLoadingLatest = false;
  bool _hasNewData = false;

  StreamSubscription<List<int>>? _batterySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _loadLatestRunData();
    _hasNewData = widget.hasNewDataFromBle;
    
    if (widget.isConnectedFromMain && widget.connectedDevice != null) {
      _initDeviceListeners(); 
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

    if (widget.isConnectedFromMain && !oldWidget.isConnectedFromMain && widget.connectedDevice != null) {
      _initDeviceListeners(); 
    }
    
    if (!widget.isConnectedFromMain && oldWidget.isConnectedFromMain) {
      _cancelListeners(); 
      setState(() => batteryLevel = 0);
    }
  }

  @override
  void dispose() {
    _cancelListeners(); 
    super.dispose();
  }

  Future<void> _initDeviceListeners() async {
    try {
      final device = widget.connectedDevice!;
      
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (mounted) {
            setState(() {
              batteryLevel = 0;
            });
            widget.onConnectionChanged?.call(false); 
          }
        }
      });

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toUpperCase().contains("180F")) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase().contains("2A19")) {
              await characteristic.setNotifyValue(true);

              _batterySubscription = characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty && mounted) {
                  setState(() {
                    batteryLevel = value[0];
                  });
                }
              });
              
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
      debugPrint("Gagal mendengarkan status device: $e");
    }
  }

  void _cancelListeners() {
    _batterySubscription?.cancel();
    _connectionSubscription?.cancel();
    _batterySubscription = null;
    _connectionSubscription = null;
  }

  // Fungsi untuk menembak waktu ke ESP32
  Future<void> syncTimeToESP32(BluetoothDevice device) async {
    try {
      // 1. Cari service dan karakteristik yang sesuai dengan ESP32 Anda
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              
              // 2. Ambil waktu saat ini dalam format Unix Timestamp (Detik)
              // millisecondsSinceEpoch dibagi 1000 agar menjadi detik (standar Unix)
              int unixTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              
              // 3. Rangkai pesan sesuai konsep Anda
              String timeCommand = "TIME:$unixTime";
              
              // 4. Tembakkan ke ESP32 secara diam-diam (push)
              await characteristic.write(utf8.encode(timeCommand), withoutResponse: true);
              
              print("Berhasil menyuapi ESP32 dengan waktu: $timeCommand");
              return;
            }
          }
        }
      }
    } catch (e) {
      print("Gagal menyinkronkan waktu ke ESP32: $e");
    }
  }

  Future<void> _loadLatestRunData() async {
      if (_latestRunData == null) {
        setState(() {
          _isLoadingLatest = false;
        });
      }

      try {
        final List<RunSession> runs = await RunHistoryStorage.getRuns();

        if (mounted) {
          setState(() {
            _latestRunData = runs.isNotEmpty ? runs.first : null;
            _isLoadingLatest = false; 
          });
        }
      } catch (e) {
        debugPrint('Error loading latest data: $e');
        if (mounted) {
          setState(() {
            _isLoadingLatest = false;
          });
        }
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

  bool get canDownload => widget.isConnectedFromMain;

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
                  color: isConnected ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected ? Colors.blue.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.check_circle : Icons.bluetooth_disabled,
                      color: isConnected ? Colors.blue : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isConnected
                            ? 'Koneksi Berhasil!'
                            : 'Chest strap tidak terhubung. Klik tombol +',
                        style: TextStyle(
                          fontSize: 12,
                          color: isConnected ? Colors.blue.shade800 : Colors.orange.shade800,
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
                    isConnected ? 'Unduh Data Lari' : 'Koneksi tidak tersedia',
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
                            Text(
                              _latestRunData != null 
                                ? _latestRunData!.title 
                                : 'Latest Run Data',
                              style: const TextStyle(
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
                                  Icons.track_changes, 
                                  'Target Pola',
                                  _latestRunData!.targetPattern,
                                  suffix: '', 
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
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // 🔥 PERBAIKAN: Mengganti kotak statis dengan kotak Swipeable
                              Expanded(
                                child: _SwipeableDashboardLrcCard(
                                  lrcData: _latestRunData!.parsedAvgLrc,
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
    final DateTime localTime = dateTime.toLocal(); 
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

// ==========================================
// 🔥 FITUR BARU: KOMPONEN SWIPEABLE UNTUK DASHBOARD
// ==========================================
class _SwipeableDashboardLrcCard extends StatefulWidget {
  final Map<String, String> lrcData;
  const _SwipeableDashboardLrcCard({required this.lrcData});

  @override
  __SwipeableDashboardLrcCardState createState() => __SwipeableDashboardLrcCardState();
}

class __SwipeableDashboardLrcCardState extends State<_SwipeableDashboardLrcCard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final entries = widget.lrcData.entries.toList();
    final bool isMulti = entries.length > 1;

    return Container(
      height: 100, // Tinggi statis agar sejajar dan PageView tidak error
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: isMulti 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.air, color: Color(0xFFF77226), size: 16),
                  SizedBox(width: 5),
                  Text(
                    'Rasio LRC Aktual',
                    style: TextStyle(color: Color(0xFFF77226), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: entries[index].value,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          TextSpan(
                            text: ' Napas:Langkah (${entries[index].key})',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Indikator Titik
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(entries.length, (index) => Container(
                  margin: const EdgeInsets.only(top: 2, left: 2, right: 2),
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index ? const Color(0xFFF77226) : Colors.orange.shade200,
                  )
                )),
              )
            ],
          )
        : Column( // TAMPILAN NORMAL (STATIS) JIKA HANYA 1 POLA
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.air, color: Color(0xFFF77226), size: 16),
                  SizedBox(width: 5),
                  Text(
                    'Rasio LRC Aktual',
                    style: TextStyle(color: Color(0xFFF77226), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: entries.isNotEmpty ? entries.first.value : '-',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: ' Napas : Langkah',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}