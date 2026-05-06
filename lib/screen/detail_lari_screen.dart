import 'package:flutter/material.dart';
import 'dart:math'; 
import '../models/run_session.dart';
import '../services/run_history_storage.dart';
import '../services/api_service.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

class DetailLariScreen extends StatefulWidget {
  final RunSession? runSession;
  final String? runId;
  final VoidCallback? onDataUpdated;

  const DetailLariScreen({
    super.key,
    this.runSession,
    this.runId,
    this.onDataUpdated,
  });

  @override
  State<DetailLariScreen> createState() => _DetailLariScreenState();
}

class _DetailLariScreenState extends State<DetailLariScreen> {
  String _currentTitle = 'Sesi Lari';
  RunSession? _runSession;
  
  bool _isLoading = true; 
  List<double> _chartData = []; 

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    String? targetId;

    if (widget.runSession != null) {
      _runSession = widget.runSession;
      _currentTitle = widget.runSession!.title;
      targetId = widget.runSession!.id;
    } else if (widget.runId != null) {
      await _loadDataFromId(widget.runId!);
      targetId = widget.runId;
    }

    if (targetId != null) {
      await _fetchRawDataForChart(targetId);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDataFromId(String id) async {
    final RunSession? run = await RunHistoryStorage.getRunById(id);
    if (!mounted || run == null) return;

    _runSession = run;
    _currentTitle = run.title;
  }

  Future<void> _fetchRawDataForChart(String id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('authToken') ?? '';

      final apiData = await ApiService.getRunDetail(token, id);
      
      final dynamic rawAny = apiData['rawLrcData'] ?? apiData['rawData'] ?? apiData['sensorData'];
      final List<dynamic>? rawData = rawAny is List ? rawAny : null; 
      
      if (rawData != null && rawData.isNotEmpty) {
        List<double> spmList = [];
        
        for (var row in rawData) {
          if (row is num) {
            spmList.add(row.toDouble());
          } else if (row is Map) {
            if (row['y'] is num) {
              spmList.add((row['y'] as num).toDouble());
            } else if (row['spm'] is num) {
              spmList.add((row['spm'] as num).toDouble());
            }
          }
        }
        
        if (mounted) {
          setState(() {
            _chartData = spmList;
          });
        }
      }
    } catch (e) {
      print('Gagal memuat grafik dari API: $e');
    }
  }

  // 🔥 FUNGSI BARU: Membuat label waktu dinamis berdasarkan durasi asli
  List<Widget> _buildDynamicTimeLabels(String? durationStr) {
    int totalSeconds = 1800; // Default 30 menit

    if (durationStr != null && durationStr.contains(':')) {
      final parts = durationStr.split(':');
      if (parts.length == 2) {
        totalSeconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      } else if (parts.length == 3) {
        totalSeconds = int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60 + int.parse(parts[2]);
      }
    }

    if (totalSeconds <= 0) totalSeconds = 1800;

    int numLabels = 7; 
    int interval = totalSeconds ~/ (numLabels - 1);

    List<Widget> labels = [];
    for (int i = 0; i < numLabels; i++) {
      int currentSeconds = i * interval;
      int m = currentSeconds ~/ 60;
      int s = currentSeconds % 60;
      String timeText = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      labels.add(_buildTimeLabel(timeText));
    }
    return labels;
  }

  Future<void> _editTitle() async {
    final TextEditingController titleController = TextEditingController(text: _currentTitle);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Judul Aktivitas'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Judul', border: OutlineInputBorder()),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final String newTitle = titleController.text.trim();
                if (newTitle.isNotEmpty) {
                  await _updateTitleInStorage(newTitle);
                  widget.onDataUpdated?.call();
                }
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF77226)),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateTitleInStorage(String newTitle) async {
    final String? id = widget.runId ?? _runSession?.id;
    if (id == null) return;
    await RunHistoryStorage.updateRunTitle(id, newTitle);
    if (!mounted) return;
    setState(() {
      _currentTitle = newTitle;
      _runSession = _runSession?.copyWith(title: newTitle);
    });
  }

  Color _getKepatuhanColor(int percent) {
    if (percent < 50) return Colors.red;
    if (percent < 80) return Colors.orange;
    return Colors.green;
  }

  String _formatDate(DateTime dateTime) {
    final DateTime localTime = dateTime.toLocal();
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${localTime.day} ${months[localTime.month - 1]} ${localTime.year}, ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';  
    }

  @override
  Widget build(BuildContext context) {
    final RunSession? session = _runSession;
    final int kepatuhanValue = session?.compliance ?? 0;
    final String displayDate = session != null ? _formatDate(session.date) : 'Tanggal tidak tersedia';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(child: Text(_currentTitle, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18))),
                const SizedBox(width: 8),
                GestureDetector(onTap: _editTitle, child: const Icon(Icons.edit, size: 18, color: Color(0xFFF77226))),
              ],
            ),
            Text(displayDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFF77226))) 
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grafik LRC', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              children: [
                // 🔥 SUMBU Y: 7 Label dengan jarak otomatis
                SizedBox(
                  height: 180,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('4:4', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('4:3', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('3:3', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('3:2', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('2:2', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('2:1', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('1:1', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 800,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Colors.grey.shade300),
                              bottom: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: CustomPaint(size: const Size(800, 180), painter: ChartPainter(_chartData)), 
                        ),
                        const SizedBox(height: 10),
                        // 🔥 SUMBU X: Label waktu dinamis
                        SizedBox(
                          width: 800,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _buildDynamicTimeLabels(session?.duration),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                _buildSummaryCard('LRC Rata-Rata', '3:2', const Color(0xFFFFF1EB)),
                const SizedBox(width: 15),
                _buildSummaryCard('Kepatuhan', '$kepatuhanValue%', const Color(0xFFFFF1EB), valueColor: _getKepatuhanColor(kepatuhanValue)),
              ],
            ),
            const SizedBox(height: 30),
            const Text('Detail Aktivitas', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF77226), fontSize: 16)),
            const Divider(color: Color(0xFFF77226), thickness: 1.5),
            _buildDetailRow(Icons.location_on_outlined, 'Jarak', '${session?.distanceLabel ?? '0'} Km'),
            _buildDetailRow(Icons.access_time, 'Durasi', session?.duration ?? '00:00'),
            _buildDetailRow(Icons.timeline, 'SPM Rata-Rata', '${session?.avgSpm ?? 0}'),
            _buildDetailRow(Icons.percent_outlined, 'Tingkat Kepatuhan', '$kepatuhanValue%', isLast: true, customValueColor: _getKepatuhanColor(kepatuhanValue)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color bgColor, {Color valueColor = Colors.black}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Color(0xFFF77226), fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: valueColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isLast = false, Color? customValueColor}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFF77226), size: 22),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Color(0xFFF77226), fontSize: 15)),
              const Spacer(),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: customValueColor ?? Colors.black)),
            ],
          ),
        ),
        if (!isLast) const Divider(color: Color(0xFFFFF1EB), thickness: 1, height: 1),
      ],
    );
  }

  Widget _buildTimeLabel(String time) {
    return SizedBox(width: 60, child: Text(time, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)));
  }
}

// 🔥 PAINTER: Menggunakan skala statis 1.0 - 7.0 agar sejajar dengan label Y
class ChartPainter extends CustomPainter {
  final List<double> dataPoints;
  const ChartPainter(this.dataPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()..color = Colors.grey.withOpacity(0.1)..strokeWidth = 1;
    for (int i = 0; i < 7; i++) {
      final double y = size.height * (i / 6);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (dataPoints.isEmpty) return;

    final Paint dataPaint = Paint()
      ..color = const Color(0xFFF77226)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path();
    double minVal = 1.0; 
    double maxVal = 7.0; 
    double range = maxVal - minVal;
    double spacing = size.width / (dataPoints.length > 1 ? dataPoints.length - 1 : 1);

    for (int i = 0; i < dataPoints.length; i++) {
      double x = i * spacing;
      double y = size.height - ((dataPoints[i] - minVal) / range * size.height);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, dataPaint);
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) => oldDelegate.dataPoints != dataPoints;
}