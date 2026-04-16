import 'package:flutter/material.dart';

class AuthorityCheckScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Authority Check",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Peringatan Bluetooth
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Bluetooth belum dihidupkan,\nHarap hidupkan >",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Nanti di sini fungsi untuk buka setting bluetooth
                    },
                    child: Row(
                      children: [
                        Text("Buka", style: TextStyle(color: Colors.red)),
                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),
            // Teks Deskripsi di bawah Card
            Text(
              "Untuk memastikan pengiriman data lari dapat dilakukan, tolong aktifkan perizinan Bluetooth di ponsel anda",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}