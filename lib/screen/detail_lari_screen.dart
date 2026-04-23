import 'package:flutter/material.dart';

import '../models/run_session.dart';
import '../services/run_history_storage.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.runSession != null) {
      _runSession = widget.runSession;
      _currentTitle = widget.runSession!.title;
    } else if (widget.runId != null) {
      _loadDataFromId(widget.runId!);
    }
  }

  Future<void> _loadDataFromId(String id) async {
    final RunSession? run = await RunHistoryStorage.getRunById(id);
    if (!mounted || run == null) return;

    setState(() {
      _runSession = run;
      _currentTitle = run.title;
    });
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
            decoration: const InputDecoration(
              labelText: 'Judul',
              hintText: 'Masukkan judul aktivitas',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String newTitle = titleController.text.trim();
                if (newTitle.isNotEmpty) {
                  await _updateTitleInStorage(newTitle);
                  widget.onDataUpdated?.call();
                }
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Judul berhasil diubah')),
                  );
                }
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

  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final RunSession? session = _runSession;
    final int kepatuhanValue = session?.compliance ?? 80;
    final String displayDate = session != null ? _formatDate(session.date) : 'Tanggal tidak tersedia';

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
                Flexible(
                  child: Text(
                    _currentTitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _editTitle,
                  child: const Icon(Icons.edit, size: 18, color: Color(0xFFF77226)),
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
            const Text('Grafik LRC', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              children: [
                const Column(
                  children: [
                    Text('4:2', style: TextStyle(fontSize: 12)),
                    SizedBox(height: 28),
                    Text('3:2', style: TextStyle(fontSize: 12)),
                    SizedBox(height: 28),
                    Text('2:1', style: TextStyle(fontSize: 12)),
                    SizedBox(height: 28),
                    Text('1:1', style: TextStyle(fontSize: 12)),
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
                              _buildTimeLabel('07:10'),
                              _buildTimeLabel('07:20'),
                              _buildTimeLabel('07:30'),
                              _buildTimeLabel('07:40'),
                              _buildTimeLabel('07:50'),
                              _buildTimeLabel('08:00'),
                              _buildTimeLabel('08:10'),
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
                _buildSummaryCard('LRC Rata-Rata', '3:2', const Color(0xFFFFF1EB)),
                const SizedBox(width: 15),
                _buildSummaryCard(
                  'Kepatuhan',
                  '$kepatuhanValue%',
                  const Color(0xFFFFF1EB),
                  valueColor: _getKepatuhanColor(kepatuhanValue),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Detail Aktivitas',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF77226), fontSize: 16),
            ),
            const SizedBox(height: 5),
            const Divider(color: Color(0xFFF77226), thickness: 1.5),
            _buildDetailRow(Icons.location_on_outlined, 'Jarak', '${session?.distanceLabel ?? '0'} Km'),
            _buildDetailRow(Icons.access_time, 'Durasi', session?.duration ?? '00:00'),
            _buildDetailRow(Icons.timeline, 'SPM Rata-Rata', '${session?.avgSpm ?? 0}'),
            _buildDetailRow(
              Icons.percent_outlined,
              'Tingkat Kepatuhan',
              '$kepatuhanValue%',
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
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: customValueColor ?? Colors.black),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(color: Color(0xFFFFF1EB), thickness: 1, height: 1),
      ],
    );
  }

  Widget _buildTimeLabel(String time) {
    return SizedBox(
      width: 60,
      child: Text(
        time,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  const ChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final double y = size.height * (i * 0.25 + 0.125);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Paint dataPaint = Paint()
      ..color = const Color(0xFFF77226)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final double targetY = size.height * 0.375;
    final Path path = Path()
      ..moveTo(0, targetY)
      ..lineTo(100, targetY - 10)
      ..lineTo(200, targetY + 20)
      ..lineTo(300, targetY - 5)
      ..lineTo(400, targetY + 15)
      ..lineTo(800, targetY);

    canvas.drawPath(path, dataPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
