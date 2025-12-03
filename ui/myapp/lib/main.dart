import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'prof_shell.dart';
import 'management_login_page.dart';
import 'home_page.dart';

import 'timetable_page.dart';

// Removed: modern_landing_page.dart, login_selection_page.dart (auth disabled)
// Authentication pages (now bypassed). Keeping imports commented for future restoration.
// import 'student_login_page.dart';
// import 'staff_login_page.dart';

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
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEEEEEE),
        primaryColor: const Color(0xFF222831),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF00ADB5),
        ),
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF222831)),
        ),
      ),
      // Auth removed: start directly at home
      initialRoute: '/home',
      routes: {
        // '/': (context) => const ModernLandingPage(),
        // '/loginSelection': (context) => const LoginSelectionPage(),
        // '/studentLogin': (context) => const StudentLoginPage(),
        // '/staffLogin': (context) => const StaffLoginPage(),
         '/home': (_) => const HomePage(),
        '/managementLogin': (context) => const ManagementLoginPage(),
       
      },
      
    );
  }
}
