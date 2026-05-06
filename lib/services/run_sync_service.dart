import 'dart:convert';
import 'dart:async'; // 🔥 Tambahan untuk Completer
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class RunSyncService {
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  StringBuffer _dataBuffer = StringBuffer();

  // 🔥 Sekarang mengembalikan Future<Map<String, dynamic>>
  Future<Map<String, dynamic>> startSync(BluetoothDevice device, String targetPattern, String jwtToken) async {
    // Completer digunakan untuk "menahan" fungsi ini sampai proses Stream BLE dan HTTP selesai
    Completer<Map<String, dynamic>> completer = Completer();

    try {
      print("Menghubungkan ke ESP32...");
      
      // 🔥 Jaring Pengaman: Memastikan ulang koneksi sebelum mencari service
      await device.connect(timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(milliseconds: 500));
      
      print("Mencari Service LRC...");
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (var service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid.toString() == characteristicUuid) {
              targetChar = char;
              break;
            }
          }
        }
      }

      if (targetChar == null) {
        throw Exception("Karakteristik tidak ditemukan!");
      }

      // 1. Mulai mendengarkan (Subscribe)
      await targetChar.setNotifyValue(true);
      targetChar.onValueReceived.listen((value) async {
        String chunk = utf8.decode(value);
        
        if (chunk == "EOF") {
          print("Semua data diterima! Memulai proses upload...");
          targetChar!.setNotifyValue(false); // Berhenti mendengarkan
          
          try {
            // TUNGGU hasil upload dari backend
            final responseJson = await _processAndUploadData(targetPattern, jwtToken);
            completer.complete(responseJson); // 🔥 Lempar hasil JSON ke DownloadDataScreen
          } catch (e) {
            completer.completeError(e); // Lempar error jika gagal upload
          }
          
        } else {
          // Kumpulkan data ke Buffer
          _dataBuffer.write(chunk);
        }
      });

      // 2. Picu ESP32 untuk mulai mengirim
      print("Mengirim perintah SYNC ke ESP32...");
      
      // 🔥 withoutResponse harus false agar Flutter menunggu struk tanda terima dari ESP32
      await targetChar.write(utf8.encode("SYNC"), withoutResponse: false);

    } catch (e) {
      // 🔥 Print error agar jika gagal lagi, penyakit aslinya terlihat di terminal
      print("========= ERROR SINKRONISASI =========");
      print(e.toString());
      print("======================================");
      completer.completeError(e);
    }

    // Fungsi akan menunggu di sini sampai completer.complete() dipanggil di atas
    return completer.future; 
  }

  // 🔥 Mengembalikan JSON Map dari Backend
  Future<Map<String, dynamic>> _processAndUploadData(String targetPattern, String jwtToken) async {
    String rawCsv = _dataBuffer.toString();
    _dataBuffer.clear(); // Kosongkan memori

    List<Map<String, dynamic>> sensorDataList = [];
    List<String> rows = rawCsv.split(";");

    for (String row in rows) {
      if (row.trim().isEmpty) continue;
      List<String> cols = row.split(",");
      if (cols.length == 4) {
        sensorDataList.add({
          "timestamp": int.parse(cols[0]),
          "breath": int.parse(cols[1]),
          "step": int.parse(cols[2]),
          "spm": int.parse(cols[3]),
        });
      }
    }

    Map<String, dynamic> payload = {
      "dateTime": DateTime.now().toUtc().toIso8601String(),
      "targetPattern": targetPattern,
      "sensorData": sensorDataList
    };

    return await ApiService.syncRunData(jwtToken, payload);
  }
}