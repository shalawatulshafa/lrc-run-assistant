import 'package:flutter/material.dart';
import 'screen/welcome_screen.dart';
import 'screen/main_navigation.dart';
import 'screen/settings_screen.dart';
import 'screen/login_screen.dart'; // Akan kita buat

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Pelari',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF77226)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/main': (context) => MainNavigation(),
        '/settings': (context) => SettingsScreen(),
      },
    );
  }
}