import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/privacy_policy_screen.dart';

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
  bool _isTimerNotificationEnabled = true;
  bool _isGoalReminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTimerNotificationEnabled = prefs.getBool('timerNotificationEnabled') ?? true;
      _isGoalReminderEnabled = prefs.getBool('goalReminderEnabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showConsentForm() {
    ConsentInformation.instance.reset();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
          () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _loadAndShowConsentForm();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Consent form is not available at this time.')),
            );
          }
        }
      },
          (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update consent info: ${error.message}')),
          );
        }
      },
    );
  }

  void _loadAndShowConsentForm() {
    ConsentForm.loadConsentForm(
          (ConsentForm consentForm) {
        consentForm.show((formError) {
          if (formError != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Consent form error: ${formError.message}')),
            );
          }
        });
      },
          (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load consent form: ${error.message}')),
          );
        }
      },
    );
  }

  void _confirmResetData() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Data'),
        content: const Text(
          'Are you sure you want to reset all activities, logs, goals, and progress? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              widget.onResetData();
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data has been reset.')),
                );
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String subject, {String body = ''}) async {
    final uri = Uri(scheme: 'mailto', path: 'lockintrackerapp@gmail.com', queryParameters: {
      'subject': subject,
      if (body.isNotEmpty) 'body': body,
    });
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(const ClipboardData(text: 'lockintrackerapp@gmail.com'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No email client; address copied to clipboard'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening email client: $e')),
        );
      }
    }
  }

  void _launchPrivacyPolicy() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ListTile(
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (v) {
                setState(() => _isDarkMode = v);
                widget.onThemeChanged(v);
              },
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Live Timer Notification'),
            subtitle: const Text('Show ongoing notification when timer is running'),
            trailing: Switch(
              value: _isTimerNotificationEnabled,
              onChanged: (value) {
                setState(() => _isTimerNotificationEnabled = value);
                _saveSetting('timerNotificationEnabled', value);
              },
            ),
          ),
          ListTile(
            title: const Text('Goal Reminders'),
            subtitle: const Text('Receive daily reminders about your goals'),
            trailing: Switch(
              value: _isGoalReminderEnabled,
              onChanged: (value) {
                setState(() => _isGoalReminderEnabled = value);
                _saveSetting('goalReminderEnabled', value);
              },
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Data & Privacy', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Ad Preferences'),
            subtitle: const Text('Manage your consent settings'),
            trailing: ElevatedButton(
              onPressed: _showConsentForm,
              child: const Text('Change'),
            ),
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            subtitle: const Text('View our privacy policy'),
            trailing: const Icon(Icons.privacy_tip, color: Colors.blue),
            onTap: _launchPrivacyPolicy,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Support', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Contact Us'),
            subtitle: const Text('Reach out for support'),
            trailing: const Icon(Icons.email, color: Colors.blue),
            onTap: () => _launchEmail('Contact LockIn Tracker Support'),
          ),
          ListTile(
            title: const Text('Report a Bug'),
            subtitle: const Text('Let us know about any issues'),
            trailing: const Icon(Icons.bug_report, color: Colors.orange),
            onTap: () => _launchEmail(
              'Bug Report',
              body: 'Describe bug:\n\nApp Version:\nDevice:\nOS:\nSteps:',
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset Data'),
            subtitle: const Text('Delete all activities, logs, and goals'),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: _confirmResetData,
          ),
        ],
      ),
    );
  }
}