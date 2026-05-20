import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/run_session.dart';
import '../services/run_history_storage.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

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
  bool _isExporting = false;
  List<LrcPoint> _chartData = [];

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
      _chartData = _runSession!.rawLrcData; 
    } else if (widget.runId != null) {
      await _loadDataFromId(widget.runId!);
      targetId = widget.runId;
    }

    if (targetId != null && _chartData.isEmpty) {
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
    _chartData = run.rawLrcData; 
  }

  Future<void> _fetchRawDataForChart(String id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('authToken') ?? '';

      final apiData = await ApiService.getRunDetail(token, id);
      
      final dynamic rawAny = apiData['rawLrcData'] ?? apiData['rawData'] ?? apiData['sensorData'];
      final List<dynamic>? rawData = rawAny is List ? rawAny : null; 
      
      if (rawData != null && rawData.isNotEmpty) {
        List<LrcPoint> pointList = [];
        
        for (var row in rawData) {
          if (row is num) {
            pointList.add(LrcPoint(y: row.toDouble(), pattern: '3:2'));
          } else if (row is Map) {
            double yVal = 0.0;
            if (row['y'] is num) {
              yVal = (row['y'] as num).toDouble();
            } else if (row['spm'] is num) {
              yVal = (row['spm'] as num).toDouble();
            }
            String pattern = row['pattern']?.toString() ?? '3:2';
            pointList.add(LrcPoint(y: yVal, pattern: pattern));
          }
        }
        
        if (mounted) {
          setState(() {
            _chartData = pointList;
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal memuat grafik dari API: $e');
    }
  }

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

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('authToken');
      if (token != null && token.isNotEmpty) {
        try {
          await ApiService.updateRunTitle(token, id, newTitle);
        } catch (e) {
          debugPrint("Gagal update backend: $e");
        }
      }
    } catch (e) {}

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
                // Swipeable LRC Card
                Expanded(
                  child: _SwipeableLrcCard(
                    lrcData: session?.parsedAvgLrc ?? {'-': '-'}
                  ),
                ),
                const SizedBox(width: 15),
                // Card Kepatuhan
                _buildSummaryCard('Kepatuhan', '$kepatuhanValue%', const Color(0xFFFFF1EB), valueColor: _getKepatuhanColor(kepatuhanValue)),
              ],
            ),
            const SizedBox(height: 30),
            const Text('Detail Aktivitas', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF77226), fontSize: 16)),
            const Divider(color: Color(0xFFF77226), thickness: 1.5),
            
            _buildDetailRow(Icons.track_changes, 'Target Pola', session?.targetPattern ?? '-'),
            _buildDetailRow(Icons.access_time, 'Durasi', session?.duration ?? '00:00'),
            _buildDetailRow(Icons.timeline, 'SPM Rata-Rata', '${session?.avgSpm ?? 0}'),
            _buildDetailRow(Icons.percent_outlined, 'Tingkat Kepatuhan', '$kepatuhanValue%', isLast: true, customValueColor: _getKepatuhanColor(kepatuhanValue)),

            const SizedBox(height: 24),
            _buildExportButton(session),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(RunSession? session) {
    final bool hasCsv = session?.rawCsv != null && session!.rawCsv!.isNotEmpty;
    final bool enabled = hasCsv && !_isExporting;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? () => _exportCsv(session) : null,
        icon: _isExporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                Icons.file_download_outlined,
                color: enabled ? Colors.white : Colors.grey.shade600,
              ),
        label: Text(
          hasCsv ? 'Ekspor CSV' : 'CSV tidak tersedia',
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFFF77226) : Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Future<void> _exportCsv(RunSession? session) async {
    if (session == null || session.rawCsv == null || session.rawCsv!.isEmpty) return;
    if (_isExporting) return;

    setState(() => _isExporting = true);
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String safeTitle = session.title
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final DateTime d = session.date.toLocal();
      final String dateStamp =
          '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      final String fileName = 'lrc_${safeTitle}_$dateStamp.csv';
      final File file = File('${tempDir.path}/$fileName');
      await file.writeAsString(session.rawCsv!);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Data Lari LRC: ${session.title}',
        text: 'Raw CSV ${session.title} (${session.duration})',
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        'Gagal mengekspor CSV: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // 🔥 PERBAIKAN: Mengatur tinggi dan padding card agar tidak overflow
  Widget _buildSummaryCard(String title, String value, Color bgColor, {Color valueColor = Colors.black}) {
    return Expanded(
      child: Container(
        height: 100, // Menambah tinggi sedikit agar tidak sesak
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), // Padding dikecilkan
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFFF77226), fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8), // Jarak di perkecil sedikit
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: valueColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isLast = false, Color? customValueColor}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              // 1. Icon Indikator
              Icon(icon, color: const Color(0xFFF77226), size: 22),
              const SizedBox(width: 14),
              
              // 2. Label Nama Variabel (Di-expand agar mengambil sisa ruang kiri)
              Expanded(
                flex: 2,
                child: Text(
                  label, 
                  style: const TextStyle(
                    color: Color(0xFFF77226), 
                    fontSize: 15,
                    fontWeight: FontWeight.w500
                  )
                ),
              ),
              
              // 3. Nilai Variabel (Rata Kanan Mutlak)
              Expanded(
                flex: 3,
                child: Text(
                  value, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 15, 
                    color: customValueColor ?? Colors.black
                  ),
                  textAlign: TextAlign.right, // Mengunci rata kanan
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(color: Color(0xFFFFF1EB), thickness: 1.2, height: 1),
      ],
    );
  }

  Widget _buildTimeLabel(String time) {
    return SizedBox(width: 60, child: Text(time, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)));
  }
}

// ==========================================
// KOMPONEN SWIPEABLE LRC CARD
// ==========================================
class _SwipeableLrcCard extends StatefulWidget {
  final Map<String, String> lrcData;
  const _SwipeableLrcCard({required this.lrcData});

  @override
  __SwipeableLrcCardState createState() => __SwipeableLrcCardState();
}

class __SwipeableLrcCardState extends State<_SwipeableLrcCard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final entries = widget.lrcData.entries.toList();
    final bool isMulti = entries.length > 1;

    return Container(
      height: 100, // Disamakan dengan Summary Card di sebelahnya
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), // Padding dikecilkan
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EB), 
        borderRadius: BorderRadius.circular(20)
      ),
      child: isMulti 
        ? Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'LRC Rata-Rata (${entries[index].key})', 
                          style: const TextStyle(color: Color(0xFFF77226), fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          entries[index].value, 
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Titik Indikator Swipe
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(entries.length, (index) => Container(
                  margin: const EdgeInsets.only(bottom: 2, left: 3, right: 3),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index ? const Color(0xFFF77226) : Colors.orange.shade200,
                  )
                )),
              )
            ],
          )
        : Column( // TAMPILAN NORMAL JIKA HANYA 1 POLA
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('LRC Rata-Rata', style: TextStyle(color: Color(0xFFF77226), fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                entries.isNotEmpty ? entries.first.value : '-', 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)
              ),
            ],
          ),
    );
  }
}

// ==========================================
// CHART PAINTER MULTI-WARNA
// ==========================================
class ChartPainter extends CustomPainter {
  final List<LrcPoint> dataPoints;
  const ChartPainter(this.dataPoints);

  // Menentukan warna berdasarkan target pola
  Color _getPatternColor(String pattern) {
    if (pattern.contains('2:1')) return Colors.blue;
    if (pattern.contains('2:2')) return Colors.green;
    if (pattern.contains('4:4')) return Colors.purple;
    if (pattern.contains('3:3')) return Colors.teal;
    return const Color(0xFFF77226); // Default Oranye untuk 3:2 dan lainnya
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()..color = Colors.grey.withOpacity(0.1)..strokeWidth = 1;
    for (int i = 0; i < 7; i++) {
      final double y = size.height * (i / 6);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (dataPoints.isEmpty) return;

    double minVal = 1.0; 
    double maxVal = 7.0; 
    double range = maxVal - minVal;
    double spacing = size.width / (dataPoints.length > 1 ? dataPoints.length - 1 : 1);

    // Menggambar per ruas agar warna bisa berubah-ubah
    for (int i = 1; i < dataPoints.length; i++) {
      double x1 = (i - 1) * spacing;
      double y1 = size.height - ((dataPoints[i - 1].y - minVal) / range * size.height);
      
      double x2 = i * spacing;
      double y2 = size.height - ((dataPoints[i].y - minVal) / range * size.height);

      final Paint segmentPaint = Paint()
        ..color = _getPatternColor(dataPoints[i].pattern)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), segmentPaint);
    }
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) => oldDelegate.dataPoints != dataPoints;
}