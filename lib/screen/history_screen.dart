import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'detail_lari_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadHistoryData();
  }

  void refreshData() {
    _loadHistoryData();
  }

  void resetData() {
    setState(() {
      _historyData = [];
      _isLoading = false;
    });
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? data = prefs.getStringList('runHistory');
      List<Map<String, dynamic>> loadedData = [];
      
      if (data != null) {
        for (String item in data) {
          try {
            Map<String, dynamic> run = jsonDecode(item);
            DateTime dateTime = DateTime.parse(run['date']);
            run['formattedDate'] = "${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.year} • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
            loadedData.add(run);
          } catch (e) {
            // Skip data yang error
          }
        }
      }
      
      loadedData.sort((a, b) => b['date'].compareTo(a['date']));
      
      setState(() {
        _historyData = loadedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getMonthName(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Ags", "Sep", "Okt", "Nov", "Des"];
    return months[month - 1];
  }

  Color _getKepatuhanColor(int percent) {
    if (percent < 50) return Colors.red;
    if (percent < 80) return Colors.orange;
    return Colors.green;
  }

  String _getLastSyncDate() {
    if (_historyData.isEmpty) return "-";
    return _historyData.first['formattedDate'] ?? "-";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text("History", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text("Belum ada riwayat lari", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text("Klik tombol + untuk memulai lari", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Top Statistics Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          _buildTopStatCard(Icons.access_time, "Sinkronisasi", _getLastSyncDate()),
                          const SizedBox(width: 15),
                          _buildTopStatCard(Icons.list_alt, "Total Sesi", "${_historyData.length} Aktivitas"),
                        ],
                      ),
                    ),
                    
                    // Title
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Riwayat Sesi Lari", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF77226))),
                      ),
                    ),
                    
                    // Divider
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(color: Color(0xFFF77226), thickness: 1),
                    ),
                    
                    // List History
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadHistoryData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _historyData.length,
                          itemBuilder: (context, index) {
                            return _buildHistoryCard(context, _historyData[index]);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTopStatCard(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        height: 75,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFF77226), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF77226),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailLariScreen(
              runId: data['id'],
              onDataUpdated: refreshData,
            ),
          ),
        );
        refreshData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: Color(0xFFF77226)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['formattedDate'],
                          style: const TextStyle(
                            color: Color(0xFFF77226),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${data['distance']} km • ${data['duration']}",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "Kepatuhan",
                  style: TextStyle(color: Colors.grey, fontSize: 9),
                ),
                const SizedBox(height: 2),
                Text(
                  "${data['compliance']}%",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _getKepatuhanColor(data['compliance']),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}