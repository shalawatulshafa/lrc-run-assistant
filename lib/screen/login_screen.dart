import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/snackbar_helper.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      SnackbarHelper.showError(context, "Email dan password harus diisi");
      return;
    }

    setState(() => _isLoading = true);

    // Simulasi proses login
    await Future.delayed(Duration(seconds: 1));

    // Simpan data user ke SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString('userName');
    String? savedEmail = prefs.getString('userEmail');

    String finalName = savedName ?? _emailController.text.split('@')[0];
    String finalEmail = savedEmail ?? _emailController.text;

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userEmail', finalEmail);
    await prefs.setString('userName', finalName);

    setState(() => _isLoading = false);

    SnackbarHelper.showSuccess(context, "Login berhasil");
    // Navigasi ke halaman utama
    Navigator.pushReplacementNamed(context, '/main');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset:
          true, // ← Tambahkan ini (default true, tapi pastikan)
      body: SafeArea(
        child: SingleChildScrollView(
          // ← BUNGKUS dengan SingleChildScrollView
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(
              context,
            ).viewInsets.bottom, // ← Tambahkan ini untuk keyboard
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 50),
                Icon(Icons.directions_run, size: 60, color: Color(0xFFF77226)),
                SizedBox(height: 20),
                Text(
                  "Login",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF77226),
                  ),
                ),
                Text(
                  "Masuk untuk melanjutkan",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: Color(0xFFF77226),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFF77226)),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next, // ← Tambahkan ini
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: Color(0xFFF77226),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFF77226)),
                    ),
                  ),
                  textInputAction: TextInputAction.done, // ← Tambahkan ini
                  onEditingComplete: _login, // ← Enter langsung login
                ),
                SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF77226),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Belum punya akun? "),
                    TextButton(
                      onPressed: () {
                        // Navigasi ke register
                      },
                      child: Text(
                        "Daftar",
                        style: TextStyle(color: Color(0xFFF77226)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30), // ← Tambahkan bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
