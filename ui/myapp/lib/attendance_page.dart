import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_page.dart';
import 'features/attendance/pages/class_selector_page.dart';
import 'features/attendance/pages/student_list_page.dart';
import 'features/attendance/pages/attendance_summary_page.dart';
import 'features/attendance/pages/student_report_page.dart';

/// Attendance Module - Dashboard with quick actions
/// Part of the unified attendance management system
///
/// Structure:
/// - lib/features/attendance/
///   ├── pages/           (All attendance screens)
///   ├── controllers/     (Riverpod state management)
///   ├── data/           (API services & models)
///   └── widgets/        (Reusable components)
class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        title: const Text(
          'Attendance',
          style: TextStyle(
            color: Color(0xFF222831),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            color: const Color(0xFF393E46),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionCard(
                context,
                title: 'Take Attendance',
                icon: Icons.how_to_reg,
                color: const Color(0xFF00ADB5),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ClassSelectorPage(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                title: 'View Summary',
                icon: Icons.analytics,
                color: const Color(0xFF393E46),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AttendanceSummaryPage(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                title: 'Student List',
                icon: Icons.people,
                color: const Color(0xFF00ADB5),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const StudentListPage(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                title: 'Student Report',
                icon: Icons.assessment,
                color: const Color(0xFF393E46),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const StudentReportPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222831),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
