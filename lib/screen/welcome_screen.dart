import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFD6885D),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 120.0, left: 30.0, right: 30.0, bottom: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello!",
                  style: TextStyle(
                    fontSize: 45,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Welcome Runners",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
                child: Column(
                  children: [
                    _buildLoginButton(
                      icon: Icons.email,
                      iconColor: Colors.blue,
                      text: "Login with Email",
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                    SizedBox(height: 20),
                    _buildLoginButton(
                      icon: Icons.person_add,
                      iconColor: Colors.green,
                      text: "Register",
                      onPressed: () {
                        // Bisa ditambahkan halaman register nanti
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Fitur akan segera hadir")),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton({required IconData icon, required Color iconColor, required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 30),
            SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}