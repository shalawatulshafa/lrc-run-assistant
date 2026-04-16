import 'package:flutter/material.dart';

class FailedScreen extends StatefulWidget {
  final String message;
  final String? subtitle;
  final VoidCallback? onRetry;

  const FailedScreen({
    super.key,
    required this.message,
    this.subtitle,
    this.onRetry,
  });

  @override
  _FailedScreenState createState() => _FailedScreenState();
}

class _FailedScreenState extends State<FailedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Error
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 60,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 30),

              // Pesan Error
              Text(
                widget.message,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle (opsional)
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 40),

              // Tombol Ulangi
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.onRetry != null) {
                      widget.onRetry!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF77226),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Ulangi",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tombol Batal (opsional)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Batal",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}