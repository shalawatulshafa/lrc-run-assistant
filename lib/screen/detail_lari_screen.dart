import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _showHistogram = false;
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

  // === Toggle Garis ↔ Bar (next to "Grafik LRC" header) ===
  Widget _buildChartModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleIconButton(
            icon: Icons.show_chart,
            isActive: !_showHistogram,
            onTap: () => setState(() => _showHistogram = false),
            tooltip: 'Grafik Garis',
          ),
          _toggleIconButton(
            icon: Icons.bar_chart,
            isActive: _showHistogram,
            onTap: () => setState(() => _showHistogram = true),
            tooltip: 'Grafik Frekuensi Pola',
          ),
        ],
      ),
    );
  }

  Widget _toggleIconButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF77226) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? Colors.white : const Color(0xFFF77226),
          ),
        ),
      ),
    );
  }

  // === Line chart (existing time-series) — di-extract jadi method ===
  Widget _buildLineChart(String? durationStr) {
    return Row(
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
                    children: _buildDynamicTimeLabels(durationStr),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // === Histogram chart: pola yang terdeteksi + frekuensi-nya ===
  Widget _buildHistogramChart() {
    final List<HistogramBar> bars = _computeHistogramData();

    if (bars.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Text(
          'Tidak ada pola signifikan untuk ditampilkan',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: CustomPaint(
        size: const Size(double.infinity, 220),
        painter: HistogramPainter(bars),
      ),
    );
  }

  // Group _chartData by actualPattern → filter low-frequency → sort desc.
  // Filter rule: hide kalau frequency <5% DAN <2 absolute count.
  List<HistogramBar> _computeHistogramData() {
    if (_chartData.isEmpty) return [];

    final Map<String, int> counts = {};
    for (final point in _chartData) {
      // Fallback ke target pattern kalau actualPattern null (data lama)
      final key = (point.actualPattern != null && point.actualPattern!.isNotEmpty)
          ? point.actualPattern!
          : point.pattern;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final int total = _chartData.length;
    final List<HistogramBar> bars = [];
    counts.forEach((pattern, count) {
      final double pct = count / total * 100;
      // Filter: <5% AND <2 cycles
      if (count < 2 && pct < 5) return;
      bars.add(HistogramBar(pattern: pattern, count: count, percentage: pct));
    });

    bars.sort((a, b) => b.count.compareTo(a.count));
    return bars;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Grafik LRC',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                _buildChartModeToggle(),
              ],
            ),
            const SizedBox(height: 20),
            if (_showHistogram)
              _buildHistogramChart()
            else
              _buildLineChart(session?.duration),
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

            // Section Analisis Mendalam — hanya muncul kalau data lari pakai format baru
            // (data lama tidak punya avgLag/phaseDrift/consistencyScore).
            if (_hasAdvancedMetrics(session)) ...[
              const SizedBox(height: 24),
              _buildAdvancedAnalysisSection(session!),
            ],

            const SizedBox(height: 24),
            _buildExportButton(session),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  bool _hasAdvancedMetrics(RunSession? session) {
    if (session == null) return false;
    return session.avgLag != null ||
        session.phaseDrift != null ||
        session.consistencyScore != null;
  }

  Widget _buildAdvancedAnalysisSection(RunSession session) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD9C2)),
      ),
      child: Theme(
        // Override Theme agar ExpansionTile divider tidak tampil saat collapsed
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: const Icon(Icons.analytics_outlined, color: Color(0xFFF77226)),
          title: const Text(
            'Analisis Mendalam',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFF77226),
              fontSize: 15,
            ),
          ),
          subtitle: const Text(
            'Tap untuk lihat metrik napas detail',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          iconColor: const Color(0xFFF77226),
          collapsedIconColor: const Color(0xFFF77226),
          children: [
            if (session.avgLag != null)
              _buildAdvancedRow(
                icon: Icons.av_timer,
                label: 'Avg Lag Napas',
                value: '${session.avgLag!.toStringAsFixed(0)} ms',
                hint: 'Rata-rata keterlambatan/kecepatan transisi napas',
              ),
            if (session.phaseDrift != null)
              _buildAdvancedRow(
                icon: session.phaseDrift! >= 0 ? Icons.trending_up : Icons.trending_down,
                label: 'Phase Drift',
                value: '${session.phaseDrift! >= 0 ? '+' : ''}${session.phaseDrift!.toStringAsFixed(1)} ms/cycle',
                hint: session.phaseDrift! >= 0
                    ? 'Napas makin tertinggal seiring waktu'
                    : 'Napas makin tepat waktu seiring waktu',
                valueColor: session.phaseDrift!.abs() < 5
                    ? Colors.green
                    : (session.phaseDrift!.abs() < 15 ? Colors.orange : Colors.red),
              ),
            if (session.consistencyScore != null)
              _buildAdvancedRow(
                icon: Icons.equalizer,
                label: 'Konsistensi',
                value: '${session.consistencyScore}/100',
                hint: 'Seberapa stabil pola napas (lebih tinggi = lebih stabil)',
                valueColor: _getConsistencyColor(session.consistencyScore!),
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }

  Color _getConsistencyColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildAdvancedRow({
    required IconData icon,
    required String label,
    required String value,
    required String hint,
    Color? valueColor,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 12, bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFF77226), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFFF77226),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: valueColor ?? Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
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
      final String safeTitle = session.title
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final DateTime d = session.date.toLocal();
      final String dateStamp =
          '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      final String fileName = 'lrc_${safeTitle}_$dateStamp.csv';

      // Buka dialog "Simpan ke..." bawaan sistem agar file langsung
      // tersimpan di lokasi pilihan user (mis. folder Download), bukan
      // dibagikan ke aplikasi lain.
      final String? savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan CSV',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: utf8.encode(session.rawCsv!),
      );

      if (!mounted) return;
      if (savedPath == null) {
        // User membatalkan dialog simpan.
        return;
      }
      SnackbarHelper.showSuccess(context, 'CSV tersimpan: $fileName');
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
                          'Rata-Rata (${entries[index].key})', 
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
              const Text('Rata-Rata', style: TextStyle(color: Color(0xFFF77226), fontWeight: FontWeight.bold, fontSize: 12)),
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

// ==========================================
// HISTOGRAM BAR DATA + PAINTER
// (frekuensi pola yang terdeteksi)
// ==========================================
class HistogramBar {
  final String pattern;
  final int count;
  final double percentage;

  const HistogramBar({
    required this.pattern,
    required this.count,
    required this.percentage,
  });
}

class HistogramPainter extends CustomPainter {
  final List<HistogramBar> bars;
  const HistogramPainter(this.bars);

  // Warna sama dengan ChartPainter agar konsisten antar mode
  Color _getPatternColor(String pattern) {
    if (pattern.contains('2:1')) return Colors.blue;
    if (pattern.contains('2:2')) return Colors.green;
    if (pattern.contains('4:4')) return Colors.purple;
    if (pattern.contains('3:3')) return Colors.teal;
    return const Color(0xFFF77226); // Default oranye untuk 3:2 dan pola lain
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    const double leftPad = 12;
    const double rightPad = 12;
    const double topPad = 30; // ruang untuk label % di atas bar
    const double bottomPad = 44; // ruang untuk pola + count di bawah bar
    const double barGap = 14; // spasi antar bar

    final double chartWidth = size.width - leftPad - rightPad;
    final double chartHeight = size.height - topPad - bottomPad;

    // Skala vertikal: pakai max percentage agar bar terbesar memenuhi tinggi
    double maxPct = 0;
    for (final b in bars) {
      if (b.percentage > maxPct) maxPct = b.percentage;
    }
    if (maxPct <= 0) maxPct = 100; // safety

    final int n = bars.length;
    final double totalGapWidth = barGap * (n - 1);
    final double barWidth = (chartWidth - totalGapWidth) / n;

    for (int i = 0; i < n; i++) {
      final HistogramBar bar = bars[i];
      final double barHeight = (bar.percentage / maxPct) * chartHeight;
      final double barLeft = leftPad + i * (barWidth + barGap);
      final double barTop = topPad + (chartHeight - barHeight);

      // Bar dengan rounded corner di atas
      final Paint paint = Paint()..color = _getPatternColor(bar.pattern);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(barLeft, barTop, barWidth, barHeight),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        paint,
      );

      // Label % di atas bar
      _paintCenteredText(
        canvas,
        text: '${bar.percentage.toStringAsFixed(0)}%',
        x: barLeft,
        y: barTop - 18,
        width: barWidth,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );

      // Label pola di bawah bar
      _paintCenteredText(
        canvas,
        text: bar.pattern,
        x: barLeft,
        y: topPad + chartHeight + 6,
        width: barWidth,
        style: TextStyle(
          color: _getPatternColor(bar.pattern),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );

      // Count di bawah label pola
      _paintCenteredText(
        canvas,
        text: '${bar.count}x',
        x: barLeft,
        y: topPad + chartHeight + 24,
        width: barWidth,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 10,
        ),
      );
    }
  }

  void _paintCenteredText(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required double width,
    required TextStyle style,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout(minWidth: width, maxWidth: width);
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(HistogramPainter oldDelegate) => oldDelegate.bars != bars;
}