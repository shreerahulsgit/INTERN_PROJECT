import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'timetable_page.dart';
import 'prof_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize core services before running app
  await TokenStorage.initialize();
  await ApiClient.initialize();

  runApp(const ProviderScope(child: CampusConnectApp()));
}

class CampusConnectApp extends StatelessWidget {
  const CampusConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CampusConnect',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00ADB5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 1,
          titleTextStyle: TextStyle(
            color: Color(0xFF00ADB5),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00ADB5),
          secondary: const Color(0xFF00ADB5),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white70),
          titleMedium: TextStyle(color: Colors.white),
        ),
        cardColor: const Color(0xFF1E1E1E),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF00ADB5),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color(0xFF00ADB5),
          unselectedItemColor: Colors.white54,
        ),
      ),
      // Start at login page
      initialRoute: '/home',
      routes: {
       
        '/home': (context) => const HomePage(),
      },
    );
  }
}
