import 'dart:async';
import 'dart:convert';
// dart:io and foundation not required now (Platform/kIsWeb handled in backend helper)
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'backend.dart';

class LabDetailPage extends StatefulWidget {
  final String labName;
  const LabDetailPage({super.key, required this.labName});

  @override
  State<LabDetailPage> createState() => _LabDetailPageState();
}

class _LabDetailPageState extends State<LabDetailPage>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  int? result;
  Timer? timer;
  final TextEditingController _urlController = TextEditingController();
  String? _errorMessage;
  bool _isProcessButtonHovered = false;
  bool _isUploadButtonHovered = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> uploadVideo() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    setState(() {
      _loading = true;
      result = 0; // start with 0
    });

    final backendBase = getBackendBaseUrl();
    final String backendUrl = '$backendBase/process_video_file';

    try {
      final req = http.MultipartRequest("POST", Uri.parse(backendUrl));
      req.files.add(await http.MultipartFile.fromPath("file", file.path));
      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200 && response.statusCode != 201) {
        setState(() {
          result = -1;
          _errorMessage =
              'Server error: ${response.statusCode} ${response.reasonPhrase}';
          _loading = false;
        });
        return;
      }
      // Poll /count every second while processing
      timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final countRes = await http.get(Uri.parse('$backendBase/count'));
          if (countRes.statusCode == 200) {
            final data = jsonDecode(countRes.body);
            setState(() {
              result = data["count"];
              _errorMessage = null;
            });
            if (data["processing"] == false) {
              timer?.cancel();
              setState(() => _loading = false);
            }
          }
        } catch (e) {
          // ignore poll errors but keep UI informed
          setState(() => _errorMessage = 'Polling error: $e');
        }
      });
    } catch (e) {
      setState(() {
        result = -1;
        _errorMessage = 'Upload error: $e';
        _loading = false;
      });
    }
  }

  Future<void> processVideoUrl(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a video URL')));
      return;
    }

    setState(() {
      _loading = true;
      result = 0;
    });

    final backendUrl = getBackendBaseUrl();

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/process_video_url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      );

      if (res.statusCode != 200 && res.statusCode != 201) {
        setState(() {
          result = -1;
          _errorMessage = 'Server error: ${res.statusCode} ${res.reasonPhrase}';
          _loading = false;
        });
        return;
      }

      // Start polling /count
      timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final countRes = await http.get(Uri.parse('$backendUrl/count'));
          if (countRes.statusCode == 200) {
            final data = jsonDecode(countRes.body);
            setState(() {
              result = data["count"];
              _errorMessage = null;
            });
            if (data["processing"] == false) {
              timer?.cancel();
              setState(() => _loading = false);
            }
          }
        } catch (e) {
          setState(() => _errorMessage = 'Polling error: $e');
        }
      });
    } catch (e) {
      setState(() {
        result = -1;
        _errorMessage = 'Request error: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _urlController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.labName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFF0F0F0F),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header card with description
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00ADB5).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.video_library,
                      color: Color(0xFF00ADB5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Video Analysis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Upload or provide a video URL to detect unique students',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // URL Input Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.link, color: Color(0xFF00ADB5), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Video URL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Enter URL or file path',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.link,
                        color: Color(0xFF00ADB5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF00ADB5),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AnimatedButton(
                    onPressed: _loading
                        ? null
                        : () => processVideoUrl(_urlController.text.trim()),
                    backgroundColor: const Color(0xFF00ADB5),
                    icon: Icons.play_circle_outline,
                    label: 'Process Video',
                    isLoading: _loading,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upload Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        color: Color(0xFF00ADB5),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Upload from Device',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AnimatedButton(
                    onPressed: _loading ? null : uploadVideo,
                    backgroundColor: const Color(0xFF00ADB5),
                    icon: Icons.video_file_outlined,
                    label: 'Select Video File',
                    isLoading: _loading,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status & Results Card
            if (_loading || result != null)
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value, child: child),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _loading
                        ? const Color(0xFF1A1A1A)
                        : (result == -1
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF1A1A1A)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _loading
                          ? const Color(0xFF00ADB5)
                          : (result == -1
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFF4CAF50)),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_loading
                                    ? const Color(0xFF00ADB5)
                                    : (result == -1
                                          ? const Color(0xFFFF6B6B)
                                          : const Color(0xFF4CAF50)))
                                .withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_loading)
                        Column(
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00ADB5),
                                ),
                                strokeWidth: 4,
                                value: null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Processing Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (result != null)
                              TweenAnimationBuilder<int>(
                                duration: const Duration(milliseconds: 300),
                                tween: IntTween(begin: 0, end: result),
                                builder: (context, value, child) => Text(
                                  'Detected so far: $value students',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        )
                      else if (result == -1)
                        Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFFF6B6B),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Processing Failed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        )
                      else if (result != null && result! >= 0)
                        Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFF4CAF50),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Detection Complete',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Total Students Detected',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TweenAnimationBuilder<int>(
                                    duration: const Duration(milliseconds: 800),
                                    tween: IntTween(begin: 0, end: result),
                                    curve: Curves.easeOut,
                                    builder: (context, value, child) => Text(
                                      '$value',
                                      style: const TextStyle(
                                        color: Color(0xFF4CAF50),
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final IconData icon;
  final String label;
  final bool isLoading;

  const _AnimatedButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
    required this.label,
    this.isLoading = false,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isPressed ? 0.9 : 1.0,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: isEnabled && !_isPressed
                ? [
                    BoxShadow(
                      color: widget.backgroundColor.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onTapDown: isEnabled
                    ? (_) => setState(() => _isPressed = true)
                    : null,
                onTapUp: isEnabled
                    ? (_) => setState(() => _isPressed = false)
                    : null,
                onTapCancel: isEnabled
                    ? () => setState(() => _isPressed = false)
                    : null,
                splashColor: Colors.white.withOpacity(0.2),
                highlightColor: Colors.white.withOpacity(0.05),
                splashFactory: InkRipple.splashFactory,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: isEnabled
                        ? LinearGradient(
                            colors: [
                              widget.backgroundColor,
                              widget.backgroundColor.withOpacity(0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isEnabled ? null : const Color(0xFF2A2A2A),
                  ),
                  child: Stack(
                    children: [
                      // Shimmer effect
                      if (isEnabled && !widget.isLoading)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _shimmerAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  _shimmerAnimation.value * 200,
                                  0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withOpacity(0.08),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      // Button content
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!widget.isLoading)
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 300),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Icon(
                                      widget.icon,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  );
                                },
                              ),
                            if (widget.isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            Text(
                              widget.label,
                              style: TextStyle(
                                color: isEnabled
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
