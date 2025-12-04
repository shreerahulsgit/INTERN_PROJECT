import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'home_page.dart'; // Ensure this points to your HomePage file

void main() {
  runApp(const MyApp());
}

const String backendBase = 'http://127.0.0.1:8000';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Connect',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B3A52),
          primary: const Color(0xFF0B3A52),
        ),
        scaffoldBackgroundColor: const Color(0xFF071425),
        textTheme: Theme.of(context)
            .textTheme
            .apply(bodyColor: Colors.white70, displayColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF092233),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          labelStyle: const TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF1AA39A),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const RegistrationPage(),
    );
  }
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _yearController = TextEditingController();
  final _otpController = TextEditingController();

  final _emailKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _regKey = GlobalKey<FormState>();

  String role = 'staff'; // 'staff' or 'student'
  bool _loading = false;
  int _currentStep = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _departmentController.dispose();
    _yearController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendOtp() async {
    if (!(_emailKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    setState(() => _loading = true);

    final url = Uri.parse('$backendBase/api/$role/send_otp');
    try {
      final res = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': email}));
      if (res.statusCode == 200) {
        _showSnack('OTP sent to $email.');
        if (!mounted) return;
        setState(() => _currentStep = 1);
      } else {
        final body = json.decode(res.body);
        _showSnack('Error: ${body['detail'] ?? res.reasonPhrase}');
      }
    } catch (e) {
      _showSnack('Request failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!(_otpKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final otp = int.tryParse(_otpController.text.trim());
    if (otp == null) return _showSnack('Enter a valid numeric OTP');

    setState(() => _loading = true);
    final url = Uri.parse('$backendBase/api/$role/verify_otp');
    try {
      final res = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': email, 'otp': otp}));
      if (res.statusCode == 200) {
        _showSnack('OTP verified.');
        if (!mounted) return;
        setState(() => _currentStep = 2);
      } else {
        final body = json.decode(res.body);
        _showSnack('Error: ${body['detail'] ?? res.reasonPhrase}');
      }
    } catch (e) {
      _showSnack('Request failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _completeRegistration() async {
    if (!(_regKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final dept = _departmentController.text.trim();
    final Map<String, dynamic> body = {'email': email, 'name': name, 'department': dept};
    if (role == 'student') body['year'] = _yearController.text.trim();

    setState(() => _loading = true);
    final url = Uri.parse('$backendBase/api/$role/register');
    try {
      final res = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));
      if (res.statusCode == 200) {
        _showSnack('Registration Successful.');
        if (!mounted) return;
        _showLoginDialog(email);
      } else {
        final b = json.decode(res.body);
        _showSnack('Error: ${b['detail'] ?? res.reasonPhrase}');
      }
    } catch (e) {
      _showSnack('Request failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loginUser(String email) async {
    setState(() => _loading = true);
    final url = Uri.parse('$backendBase/api/$role/login');
    try {
      final res = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': email}));
      if (res.statusCode == 200) {
        _showSnack('Login Successful.');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        final body = json.decode(res.body);
        _showSnack('Login Failed: ${body['detail'] ?? res.reasonPhrase}');
      }
    } catch (e) {
      _showSnack('Request failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showLoginDialog(String email) {
  showDialog(
    context: context, // page context
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF0B2430),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Login', style: TextStyle(color: Colors.white)),
        content: const Text('Do you want to login now?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // just close dialog
            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // close dialog first
              // Navigate in next frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.pushReplacement(
                  context, // use page context, not dialogContext
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              });
            },
            child: const Text('Login', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      );
    },
  );
}

  void _showLoginEmailDialog() {
    final _loginEmailController = TextEditingController();

    showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0B2430),
            title: const Text('Login', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: _loginEmailController,
              decoration: const InputDecoration(
                labelText: 'College Email',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.email, color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.redAccent))),
              TextButton(
                onPressed: () {
                  final email = _loginEmailController.text.trim();
                  if (email.isEmpty) {
                    _showSnack('Enter your email');
                    return;
                  }
                  Navigator.pop(context);
                  _loginUser(email);
                },
                child: const Text('Login',
                    style: TextStyle(color: Colors.greenAccent)),
              ),
            ],
          );
        });
  }

  void _resetAll() {
    if (!mounted) return;
    setState(() {
      _currentStep = 0;
      _emailController.clear();
      _otpController.clear();
      _nameController.clear();
      _departmentController.clear();
      _yearController.clear();
    });
  }

  void _resetStaff() {
    if (role == 'staff') _resetAll();
  }

  void _resetStudent() {
    if (role == 'student') _resetAll();
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF1AA39A);
    final bg = const Color(0xFF071425);
    final cardColor = const Color(0xFF0B2430);

    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              color: cardColor,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white10,
                          child: const Icon(Icons.school,
                              color: Colors.white, size: 40)),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Text(
                              role == 'staff'
                                  ? 'STAFF REGISTER'
                                  : 'STUDENT REGISTER',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: accent)),
                          const SizedBox(height: 4),
                          Text('Campus Connect',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRoleToggle(),
                    const SizedBox(height: 18),
                    _buildStepContent(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading
                                ? null
                                : () async {
                                    if (_currentStep == 0) await _sendOtp();
                                    else if (_currentStep == 1) await _verifyOtp();
                                    else await _completeRegistration();
                                  },
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(_currentStep == 0
                                    ? 'Send OTP'
                                    : _currentStep == 1
                                        ? 'Confirm OTP'
                                        : 'Register'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _showLoginEmailDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D9FF),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Already have an account? Login'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loading
                          ? null
                          : role == 'staff'
                              ? _resetStaff
                              : _resetStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    final accent = const Color(0xFF00D9FF);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _currentStep == 0 ? () => setState(() => role = 'staff') : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: role == 'staff' ? accent : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    'Staff',
                    style: TextStyle(
                      color: role == 'staff' ? const Color(0xFF071425) : Colors.white38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: _currentStep == 0 ? () => setState(() => role = 'student') : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: role == 'student' ? accent : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    'Student',
                    style: TextStyle(
                      color: role == 'student' ? const Color(0xFF071425) : Colors.white38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return Form(
        key: _emailKey,
        child: TextFormField(
          controller: _emailController,
          decoration:
              const InputDecoration(labelText: 'College Email', prefixIcon: Icon(Icons.email)),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter email';
            if (!v.trim().endsWith('@citchennai.net'))
              return 'Use your college email (@citchennai.net)';
            final localPart = v.trim().split('@')[0];
            if (role == 'staff' && localPart.contains('.'))
              return 'Staff email must be name@citchennai.net';
            if (role == 'student') {
              if (!RegExp(r'^[a-zA-Z]+[.][a-zA-Z]+[0-9]{4}$').hasMatch(localPart)) {
                return 'Student email format: name.departmentYear (e.g., vithunas.csbs2023)';
              }
            }
            return null;
          },
        ),
      );
    }
    if (_currentStep == 1) {
      return Form(
        key: _otpKey,
        child: TextFormField(
          controller: _otpController,
          decoration:
              const InputDecoration(labelText: 'OTP', prefixIcon: Icon(Icons.confirmation_number)),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter OTP';
            if (int.tryParse(v.trim()) == null) return 'Invalid OTP';
            return null;
          },
        ),
      );
    }
    return Form(
      key: _regKey,
      child: Column(
        children: [
          TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null),
          if (role == 'student') ...[
            const SizedBox(height: 12),
            TextFormField(
                controller: _departmentController,
                decoration:
                    const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.apartment)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter department' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _yearController,
                decoration:
                    const InputDecoration(labelText: 'Batch/Year', prefixIcon: Icon(Icons.calendar_month)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter batch/year' : null),
          ]
        ],
      ),
    );
  }
}
