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
    Completer<Map<String, dynamic>> completer = Completer();

    try {
      print("Menghubungkan ke ESP32...");
      await device.connect(timeout: const Duration(seconds: 5));
      
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

      targetChar.lastValueStream.listen((value) async {
        if (value.isNotEmpty) {
          String chunk = utf8.decode(value);

          if (chunk.contains("EOF")) {
            print("Menerima EOF. Sinkronisasi dari alat selesai.");
            _dataBuffer.write(chunk.replaceAll("EOF", "")); 
            
            try {
              // Mulai proses upload setelah semua data ditarik
              var result = await _processAndUploadData(jwtToken);
              completer.complete(result);
            } catch (e) {
              completer.completeError(e);
            }
          } else {
            // Sambung terus data yang terpotong-potong
            _dataBuffer.write(chunk);
          }
        }
      });

      // 🔥 1. TAMBAHAN: TEMBAK WAKTU TERLEBIH DAHULU
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
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future; 
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