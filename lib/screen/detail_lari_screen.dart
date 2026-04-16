import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DetailLariScreen extends StatefulWidget {
  final Map<String, dynamic>? runData;
  final String? runTitle;
  final String? runId;
  final VoidCallback? onDataUpdated;

  const DetailLariScreen({
    super.key, 
    this.runData, 
    this.runTitle, 
    this.runId,
    this.onDataUpdated,
  });

  @override
  State<DetailLariScreen> createState() => _DetailLariScreenState();
}

class _DetailLariScreenState extends State<DetailLariScreen> {
  String _currentTitle = "Sesi Lari"; // 🔥 LANGSUNG DIISI DEFAULT
  Map<String, dynamic> _runData = {}; // 🔥 LANGSUNG DIISI DEFAULT

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.runData != null) {
      // Data baru dari download
      _runData = Map.from(widget.runData!);
      _currentTitle = widget.runTitle ?? "Sesi Lari";
    } else if (widget.runId != null) {
      _loadDataFromId(widget.runId!);
    }
  }

  Future<void> _loadDataFromId(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? data = prefs.getStringList('runHistory');
    
    if (data != null && mounted) {
      for (String item in data) {
        Map<String, dynamic> run = jsonDecode(item);
        if (run['id'] == id) {
          setState(() {
            _runData = run;
            _currentTitle = run['title'] ?? "Sesi Lari";
          });
          break;
        }
      }
    }
  }

  Future<void> _editTitle() async {
    TextEditingController titleController = TextEditingController(text: _currentTitle);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Judul Aktivitas"),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: "Judul",
              hintText: "Masukkan judul aktivitas",
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                String newTitle = titleController.text.trim();
                if (newTitle.isNotEmpty) {
                  setState(() {
                    _currentTitle = newTitle;
                  });
                  await _updateTitleInStorage(newTitle);
                  
                  if (mounted && widget.onDataUpdated != null) {
                    widget.onDataUpdated!();
                  }
                }
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Judul berhasil diubah")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF77226)),
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateTitleInStorage(String newTitle) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? historyData = prefs.getStringList('runHistory');
    
    if (historyData != null) {
      List<String> updatedData = [];
      for (String item in historyData) {
        Map<String, dynamic> run = jsonDecode(item);
        if (run['id'] == widget.runId) {
          run['title'] = newTitle;
        }
        updatedData.add(jsonEncode(run));
      }
      await prefs.setStringList('runHistory', updatedData);
    }
  }

  Color _getKepatuhanColor(int percent) {
    if (percent < 50) return Colors.red;
    if (percent < 80) return Colors.orange;
    return Colors.green;
  }

  String _getMonthName(int month) {
    const months = [
      "Januari", "Februari", "Maret", "April", "Mei", "Juni",
      "Juli", "Agustus", "September", "Oktober", "November", "Desember"
    ];
    return months[month - 1];
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime dateTime;
      if (dateValue is DateTime) {
        dateTime = dateValue;
      } else if (dateValue is String) {
        dateTime = DateTime.parse(dateValue);
      } else {
        return "Tanggal tidak tersedia";
      }
      return "${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Tanggal tidak tersedia";
    }
  }

  @override
  Widget build(BuildContext context) {
    int kepatuhanValue = _runData['compliance'] ?? 80;
    
    // 🔥 AMBIL TANGGAL DENGAN BENAR
    String displayDate = "";
    if (widget.runData != null && widget.runData!['dateTime'] != null) {
      displayDate = _formatDate(widget.runData!['dateTime']);
    } else if (_runData['date'] != null) {
      displayDate = _formatDate(_runData['date']);
    } else {
      displayDate = "Tanggal tidak tersedia";
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _currentTitle,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _editTitle,
                  child: Icon(Icons.edit, size: 18, color: const Color(0xFFF77226)),
                ),
              ],
            ),
            Text(
              displayDate,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Grafik LRC", 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              children: [
                const Column(
                  children: [
                    Text("4:2", style: TextStyle(fontSize: 12)), SizedBox(height: 28),
                    Text("3:2", style: TextStyle(fontSize: 12)), SizedBox(height: 28),
                    Text("2:1", style: TextStyle(fontSize: 12)), SizedBox(height: 28),
                    Text("1:1", style: TextStyle(fontSize: 12)),
                  ],
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
                          child: const CustomPaint(painter: ChartPainter()),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 800,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTimeLabel("07:10"), _buildTimeLabel("07:20"),
                              _buildTimeLabel("07:30"), _buildTimeLabel("07:40"),
                              _buildTimeLabel("07:50"), _buildTimeLabel("08:00"),
                              _buildTimeLabel("08:10"),
                            ],
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
                _buildSummaryCard("LRC Rata-Rata", "3:2", const Color(0xFFFFF1EB)),
                const SizedBox(width: 15),
                _buildSummaryCard(
                  "Kepatuhan", 
                  "$kepatuhanValue%", 
                  const Color(0xFFFFF1EB), 
                  valueColor: _getKepatuhanColor(kepatuhanValue),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text("Detail Aktivitas", 
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF77226), fontSize: 16)),
            const SizedBox(height: 5),
            const Divider(color: Color(0xFFF77226), thickness: 1.5),
            
            _buildDetailRow(Icons.location_on_outlined, "Jarak", "${_runData['distance'] ?? 2.3} Km"),
            _buildDetailRow(Icons.access_time, "Durasi", _runData['duration'] ?? "42 : 31"),
            _buildDetailRow(Icons.timeline, "SPM Rata-Rata", "${_runData['avgSpm'] ?? 164}"),
            _buildDetailRow(
              Icons.percent_outlined, 
              "Tingkat Kepatuhan", 
              "$kepatuhanValue%", 
              isLast: true, 
              customValueColor: _getKepatuhanColor(kepatuhanValue),
            ),
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

class ChartPainter extends CustomPainter {
  const ChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    var gridPaint = Paint()..color = Colors.grey.withValues(alpha: 0.2)..strokeWidth = 1; // 🔥 Ganti withOpacity
    for (int i = 0; i < 4; i++) {
      double y = size.height * (i * 0.25 + 0.125);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    var dataPaint = Paint()..color = const Color(0xFFF77226)..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
    double targetY = size.height * 0.375;
    var path = Path();
    path.moveTo(0, targetY);
    path.lineTo(100, targetY - 10);
    path.lineTo(200, targetY + 20);
    path.lineTo(300, targetY - 5);
    path.lineTo(400, targetY + 15);
    path.lineTo(800, targetY);
    canvas.drawPath(path, dataPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}