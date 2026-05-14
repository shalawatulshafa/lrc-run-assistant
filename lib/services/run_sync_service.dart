import 'dart:convert';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'api_service.dart';

class RunSyncService {
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  StringBuffer _dataBuffer = StringBuffer();

  /// Menjalankan proses sinkronisasi dari awal (Koneksi -> Ambil Data -> Upload)
  Future<Map<String, dynamic>> startSync(
      BluetoothDevice device, String fallbackPattern, String jwtToken) async {
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
        throw Exception("Karakteristik sensor tidak ditemukan.");
      }

      _dataBuffer.clear();
      print("Mengaktifkan Notifikasi...");
      await targetChar.setNotifyValue(true);

      // Mendengarkan data yang masuk dari ESP32
      StreamSubscription? subscription;
      subscription = targetChar.onValueReceived.listen((value) async {
        String receivedData = utf8.decode(value);
        print("Menerima: $receivedData");

        if (receivedData.contains("EOF")) {
          print("Semua data diterima. Memproses...");
          await subscription?.cancel();
          
          try {
            // Upload ke backend
            final result = await _processAndUploadData(fallbackPattern, jwtToken);
            completer.complete(result);
          } catch (e) {
            completer.completeError(e);
          }
        } else {
          _dataBuffer.write(receivedData);
        }
      });

      // Mengirim perintah "SYNC" ke ESP32 untuk mulai mengirim data
      print("Mengirim perintah SYNC...");
      await targetChar.write(utf8.encode("SYNC"), withoutResponse: false);

    } catch (e) {
      print("========= ERROR SINKRONISASI =========");
      print(e.toString());
      print("======================================");
      completer.completeError(e);
    }

    return completer.future; 
  }

  /// Mengolah Buffer CSV dan mengirimnya ke API Backend
  Future<Map<String, dynamic>> _processAndUploadData(
      String fallbackPattern, String jwtToken) async {
    
    String rawCsv = _dataBuffer.toString();
    _dataBuffer.clear(); // Bersihkan memori

    if (rawCsv.trim().isEmpty) {
      throw Exception("Data dari alat kosong.");
    }

    // Mencoba mendeteksi pattern ID dari data baris pertama
    // Format ESP32: timestamp,breath,step,spm,patternId;
    List<String> rows = rawCsv.split(";");
    String finalPatternId = fallbackPattern; 

    for (String row in rows) {
      if (row.trim().isEmpty) continue;
      List<String> cols = row.split(",");
      if (cols.length >= 5) {
        // Ambil kolom ke-5 (index 4) sebagai pattern ID resmi dari alat
        finalPatternId = cols[4].trim(); 
        break; 
      }
    }

    print("Mendektesi Pola ID: $finalPatternId");

    // Mengirim ke backend lewat ApiService
    // Pastikan ApiService.syncRun menerima (jwtToken, dateTime, targetPattern, rawData)
    final response = await ApiService.syncRun(
      jwtToken: jwtToken,
      dateTime: DateTime.now().toIso8601String(),
      targetPattern: finalPatternId, // Mengirim "0" atau "1"
      rawData: rawCsv,
    );

    return response;
  }
}