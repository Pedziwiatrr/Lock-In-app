import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final void Function(bool) onThemeChanged;
  final VoidCallback onResetData;

  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onResetData,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  void _confirmResetData() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'Are you sure you want to reset all activities, logs, and goals? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onResetData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data has been reset.')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String subject, {String body = ''}) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'lockintrackerapp@gmail.com',
      queryParameters: {
        'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(const ClipboardData(text: 'lockintrackerapp@gmail.com'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No email client found. Email address copied to clipboard: lockintrackerapp@gmail.com',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening email client: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                  widget.onThemeChanged(value);
                },
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Reset All Data'),
              subtitle: const Text('Delete all activities, logs, and goals.'),
              trailing: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: _confirmResetData,
            ),
            const Divider(),
            ListTile(
              title: const Text('Contact Us'),
              subtitle: const Text('Reach out to our support team.'),
              trailing: const Icon(Icons.email, color: Colors.blue),
              onTap: () => _launchEmail('Contact LockIn Tracker Support'),
            ),
            const Divider(),
            ListTile(
              title: const Text('Report a Bug'),
              subtitle: const Text('Let us know about any issues.'),
              trailing: const Icon(Icons.bug_report, color: Colors.orange),
              onTap: () => _launchEmail(
                'Bug Report for LockIn Tracker',
                body: 'Please describe the bug you encountered:\n\nApp Version: [Your App Version]\nDevice: [Your Device]\nOS: [Your OS Version]\nSteps to Reproduce:\n1. \n2. \n3. \nDescription of the Issue:\n',
              ),
            ),
          ],
        ),
      ),
    );
  }
}