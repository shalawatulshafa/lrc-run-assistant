// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screen/welcome_screen.dart';
import 'screen/main_navigation.dart';
import 'screen/settings_screen.dart';
import 'screen/login_screen.dart';
import 'screen/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi ke portrait-up saja (tidak termasuk upside-down)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  
  // Update constructor untuk menerima isLoggedIn
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Pelari',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF77226)),
        useMaterial3: true,
      ),
      // 4. Atur initialRoute berdasarkan status login
      initialRoute: isLoggedIn ? '/main' : '/',
      routes: {
        '/': (context) => WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainNavigation(),
        '/settings': (context) => const SettingsScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}