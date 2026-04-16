// models/chest_strap_data.dart
class ChestStrapData {
  final bool hasNewData;      // Apakah ada data baru?
  final DateTime? lastSync;    // Kapan terakhir sync?
  final int dataCount;         // Jumlah data mentah
  
  ChestStrapData({
    this.hasNewData = false,
    this.lastSync,
    this.dataCount = 0,
  });
}