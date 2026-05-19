import 'dart:convert';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'api_service.dart';

class RunSyncService {
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  StringBuffer _dataBuffer = StringBuffer();

  // 🔥 FITUR BARU: Fungsi untuk memutus koneksi secara manual
  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      print("Memutus koneksi dari ${device.platformName}...");
      await device.disconnect();
      print("Koneksi berhasil diputus.");
    } catch (e) {
      print("Gagal memutus koneksi: $e");
    }
  }

  /// Menjalankan proses sinkronisasi dari awal (Koneksi -> Ambil Data -> Upload)
  Future<Map<String, dynamic>> startSync(
      BluetoothDevice device, String jwtToken) async {
    final Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
    StreamSubscription<List<int>>? dataSubscription;
    StreamSubscription<BluetoothConnectionState>? connectionSubscription;

    // Defensive: pastikan buffer bersih dari sisa sync sebelumnya
    _dataBuffer.clear();

    void completeWithError(Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    void completeWithSuccess(Map<String, dynamic> result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    try {
      print("Menghubungkan ke ESP32...");
      await device.connect(timeout: const Duration(seconds: 5));

      // Pantau status koneksi: bila alat disconnect saat sync berjalan, fail-fast
      connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          completeWithError(
            Exception("Koneksi ke alat terputus saat mengunduh data."),
          );
        }
      });

      // Jeda singkat agar koneksi stabil sebelum mencari service
      await Future.delayed(const Duration(milliseconds: 500));

      print("Mencari Service LRC...");
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (var s in services) {
        if (s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              targetChar = c;
              break;
            }
          }
        }
      }

      if (targetChar == null) {
        throw Exception("Karakteristik Bluetooth tidak ditemukan pada alat.");
      }

      print("Mendaftar untuk Notifikasi BLE...");
      await targetChar.setNotifyValue(true);

      dataSubscription = targetChar.lastValueStream.listen((value) async {
        if (value.isNotEmpty) {
          String chunk = utf8.decode(value);

          if (chunk.contains("EOF")) {
            print("Menerima EOF. Sinkronisasi dari alat selesai.");
            // Kontrak firmware: terminator adalah literal "EOF;".
            // Strip varian dengan semicolon dulu, lalu fallback "EOF" mentah
            // untuk kasus chunk terpotong tepat di antara 'F' dan ';'.
            _dataBuffer.write(chunk.replaceAll("EOF;", "").replaceAll("EOF", ""));

            // Stop listener begitu EOF diterima — kita commit ke proses upload
            await dataSubscription?.cancel();
            dataSubscription = null;

            // Race guard: kalau sudah errored (mis. disconnect race), jangan upload
            if (completer.isCompleted) return;

            try {
              final result = await _processAndUploadData(jwtToken);
              completeWithSuccess(result);
            } catch (e) {
              completeWithError(e);
            }
          } else {
            _dataBuffer.write(chunk);
          }
        }
      });

      // 🔥 1. TEMBAK WAKTU TERLEBIH DAHULU
      print("Mengirim sinkronisasi waktu ke ESP32...");
      int unixTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      String timeCommand = "TIME:$unixTime";
      await targetChar.write(utf8.encode(timeCommand), withoutResponse: false);

      // 🔥 2. JEDA SEJENAK: Beri waktu ESP32 untuk mengatur jam RTC-nya
      await Future.delayed(const Duration(milliseconds: 500));

      // 🔥 3. BARU KIRIM SYNC
      print("Mengirim perintah SYNC ke ESP32...");
      await targetChar.write(utf8.encode("SYNC"), withoutResponse: false);
    } catch (e) {
      print("========= ERROR SINKRONISASI =========");
      print(e.toString());
      print("======================================");
      completeWithError(e);
    }

    return completer.future
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception(
            "Sinkronisasi terlalu lama (>60 detik). Pastikan alat menyala dan dekat dengan HP, lalu coba lagi.",
          ),
        )
        .whenComplete(() async {
          await dataSubscription?.cancel();
          await connectionSubscription?.cancel();
        });
  }

  /// Mengolah Buffer CSV dan mengirimnya ke API Backend
  Future<Map<String, dynamic>> _processAndUploadData(String jwtToken) async {
    
    String rawCsv = _dataBuffer.toString();
    _dataBuffer.clear(); // Bersihkan memori HP

    if (rawCsv.trim().isEmpty) {
      throw Exception("Data dari alat kosong.");
    }

    print("Mengirim data CSV Multi-Sesi ke Backend...");

    // Langsung tembak ke backend tanpa perlu memecah atau menebak pola
    return await ApiService.syncRun(
      jwtToken: jwtToken,
      rawData: rawCsv,
    );
  }
}