import 'package:flutter/material.dart';

/// Notification Settings Page - Manage notification preferences
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Notification preferences stored in local state
  bool _appNotifications = true;
  bool _attendanceAlerts = true;
  bool _timetableUpdates = false;
  bool _systemUpdates = true;
  bool _emailNotifications = false;
  bool _pushNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Text(
              'Manage your notification preferences',
              style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
            ),
          ),

          // General Notifications Section
          _buildSectionHeader('General Notifications'),
          const SizedBox(height: 8),
          _buildNotificationCard(
            title: 'App Notifications',
            subtitle: 'Receive all app notifications',
            icon: Icons.notifications_outlined,
            value: _appNotifications,
            onChanged: (value) {
              setState(() {
                _appNotifications = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildNotificationCard(
            title: 'Push Notifications',
            subtitle: 'Receive push notifications on your device',
            icon: Icons.phone_android_outlined,
            value: _pushNotifications,
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildNotificationCard(
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            icon: Icons.email_outlined,
            value: _emailNotifications,
            onChanged: (value) {
              setState(() {
                _emailNotifications = value;
              });
            },
          ),

          const SizedBox(height: 32),

          // Activity Notifications Section
          _buildSectionHeader('Activity Notifications'),
          const SizedBox(height: 8),
          _buildNotificationCard(
            title: 'Attendance Alerts',
            subtitle: 'Get notified about attendance updates',
            icon: Icons.event_available_outlined,
            value: _attendanceAlerts,
            onChanged: (value) {
              setState(() {
                _attendanceAlerts = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildNotificationCard(
            title: 'Timetable Updates',
            subtitle: 'Get notified about timetable changes',
            icon: Icons.schedule_outlined,
            value: _timetableUpdates,
            onChanged: (value) {
              setState(() {
                _timetableUpdates = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildNotificationCard(
            title: 'System Updates',
            subtitle: 'Get notified about system announcements',
            icon: Icons.update_outlined,
            value: _systemUpdates,
            onChanged: (value) {
              setState(() {
                _systemUpdates = value;
              });
            },
          ),

          const SizedBox(height: 32),

          // Save Preferences Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF555555),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your notification preferences are saved automatically',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: value ? Colors.black : Colors.grey,
            size: 24,
          ),
        ),
        activeThumbColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
