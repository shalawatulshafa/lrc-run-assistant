// lib/helpers/run_title_helper.dart
import 'package:flutter/material.dart';

class RunTitleHelper {
  // Fungsi untuk menentukan waktu dalam sehari
  static String getTimeOfDay(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 4 && hour < 10) return "Pagi";
    if (hour >= 10 && hour < 15) return "Siang";
    if (hour >= 15 && hour < 18) return "Sore";
    if (hour >= 18 && hour < 22) return "Malam";
    return "Dini Hari";
  }

  // Fungsi untuk menentukan tipe aktivitas berdasarkan data lari
  static String getActivityType(double distance, double avgSpm, int compliance) {
    if (distance >= 10) return "Long Run";
    if (distance >= 5 && distance < 10) return "Lari Jarak Jauh";
    if (avgSpm >= 180) return "Sprint Training";
    if (avgSpm >= 160 && avgSpm < 180) return "Interval Training";
    if (compliance >= 90) return "Lari Optimal";
    if (compliance >= 70 && compliance < 90) return "Lari Rutin";
    if (distance < 3) return "Lari Pemulihan";
    return "Lari Santai";
  }

  // Fungsi utama untuk generate judul otomatis
  static String generateTitle(DateTime dateTime, double distance, double avgSpm, int compliance) {
    String timeOfDay = getTimeOfDay(dateTime);
    String activityType = getActivityType(distance, avgSpm, compliance);
    return "$timeOfDay ${distance.toStringAsFixed(1)}km - $activityType";
  }
}