import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'lab_detail_page.dart';
import 'backend.dart';

class OccupancyPage extends StatefulWidget {
  const OccupancyPage({super.key});

  @override
  State<OccupancyPage> createState() => _OccupancyPageState();
}

class _OccupancyPageState extends State<OccupancyPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final String backend = getBackendBaseUrl();

  int labA1 = 0, labA2 = 0, labB1 = 0, labB2 = 0, labC1 = 0;
  bool processing = false;

  Timer? timer;
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    startPolling();
  }

  @override
  void dispose() {
    _tabController.dispose();
    timer?.cancel();
    super.dispose();
  }

  void startPolling() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final res = await http.get(Uri.parse("$backend/count"));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          setState(() {
            labA1 = data["labA1"] ?? 0;
            labA2 = data["labA2"] ?? 0;
            labB1 = data["labB1"] ?? 0;
            labB2 = data["labB2"] ?? 0;
            labC1 = data["labC1"] ?? 0;
            processing = data["processing"] ?? false;
          });
        }
      } catch (e) {
        // silently ignore errors
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Lab Occupancy',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00ADB5),
              indicatorWeight: 3,
              labelColor: const Color(0xFF00ADB5),
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Labs'),
                Tab(text: 'Classrooms'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLabsView(), _buildClassroomsView()],
      ),
    );
  }

  Widget _buildLabsView() {
    final labs = [
      {
        "name": "Python LAB",
        "count": labA1,
        "capacity": 30,
        "icon": Icons.developer_board,
      },
      {
        "name": "Network LAB",
        "count": labA2,
        "capacity": 30,
        "icon": Icons.router,
      },
      {
        "name": "Language LAB",
        "count": labB1,
        "capacity": 25,
        "icon": Icons.translate,
      },
      {"name": "Mock LAB", "count": labB2, "capacity": 25, "icon": Icons.quiz},
      {"name": "ILP LAB", "count": labC1, "capacity": 30, "icon": Icons.school},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: labs.length,
      itemBuilder: (context, index) {
        final lab = labs[index];
        double percentage = (lab["capacity"] as int > 0)
            ? ((lab["count"] as int) / (lab["capacity"] as int)) * 100
            : 0.0;

        Color iconColor;
        if (percentage >= 90) {
          iconColor = const Color(0xFFFF6B6B);
        } else if (percentage >= 70) {
          iconColor = const Color(0xFFFFD93D);
        } else if (percentage > 0) {
          iconColor = const Color(0xFF00ADB5);
        } else {
          iconColor = Colors.white30;
        }

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    LabDetailPage(labName: lab["name"] as String),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      var tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        lab["icon"] as IconData,
                        color: iconColor,
                        size: 24,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: iconColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (lab["count"] as int).toString(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  lab["name"] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    tween: Tween<double>(begin: 0, end: percentage / 100),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor: AlwaysStoppedAnimation(iconColor),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClassroomsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOccupancyCard('Room 101', 45, 50, Icons.meeting_room, false),
        const SizedBox(height: 12),
        _buildOccupancyCard('Room 102', 50, 50, Icons.class_, false),
        const SizedBox(height: 12),
        _buildOccupancyCard('Room 201', 30, 60, Icons.school, false),
        const SizedBox(height: 12),
        _buildOccupancyCard('Room 202', 0, 60, Icons.door_front_door, false),
        const SizedBox(height: 12),
        _buildOccupancyCard('Room 301', 55, 80, Icons.apartment, false),
      ],
    );
  }

  Widget _buildOccupancyCard(
    String name,
    int occupied,
    int capacity,
    IconData icon,
    bool processing,
  ) {
    final double percentage = (capacity > 0)
        ? (occupied / capacity) * 100
        : 0.0;

    Color statusColor;

    if (percentage >= 90) {
      statusColor = const Color(0xFFFF6B6B);
    } else if (percentage >= 70) {
      statusColor = const Color(0xFFFFD93D);
    } else if (percentage > 0) {
      statusColor = const Color(0xFF00ADB5);
    } else {
      statusColor = Colors.white30;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                LabDetailPage(labName: name),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 0.1);
                  const end = Offset.zero;
                  const curve = Curves.easeOut;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  var fadeAnimation = Tween<double>(
                    begin: 0.0,
                    end: 1.0,
                  ).animate(CurvedAnimation(parent: animation, curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: FadeTransition(opacity: fadeAnimation, child: child),
                  );
                },
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: statusColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        processing
                            ? "Processing..."
                            : "$occupied / $capacity occupied",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                tween: Tween<double>(begin: 0, end: percentage / 100),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}