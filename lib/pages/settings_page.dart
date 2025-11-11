import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/privacy_policy_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

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
      _isTimerNotificationEnabled =
          prefs.getBool('timerNotificationEnabled') ?? true;
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
              const SnackBar(
                  content: Text('Consent form is not available at this time.')),
            );
          }
        }
      },
          (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to update consent info: ${error.message}')),
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
            SnackBar(
                content: Text('Failed to load consent form: ${error.message}')),
          );
        }
      },
    );
  }

  Future<String> _getBackupJsonString() async {
    final prefs = await SharedPreferences.getInstance();
    final allData = <String, dynamic>{};

    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key == 'launchCount') continue;
      if (key == 'activities' || key == 'activityLogs' || key == 'goals') {
        final jsonString = prefs.getString(key);
        if (jsonString != null && jsonString.isNotEmpty) {
          allData[key] = jsonDecode(jsonString);
        } else {
          allData[key] = [];
        }
      } else {
        allData[key] = prefs.get(key);
      }
    }
    return jsonEncode(allData);
  }

  Future<void> _exportData() async {
    try {
      final jsonString = await _getBackupJsonString();
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/lockin_backup.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'LockIn Tracker Backup',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final allData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (!allData.containsKey('activities') ||
          !allData.containsKey('activityLogs') ||
          !allData.containsKey('goals')) {
        throw Exception('Invalid backup file structure.');
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Import'),
          content:
          const Text('This can possibly overwrite current data. Are you sure?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import')),
          ],
        ),
      );

      if (confirmed != true) return;

      final prefs = await SharedPreferences.getInstance();

      final int currentLaunchCount = prefs.getInt('launchCount') ?? 1;

      await prefs.clear();

      for (var entry in allData.entries) {
        final key = entry.key;
        final value = entry.value;

        if (key == 'activities' || key == 'activityLogs' || key == 'goals') {
          if (value is String) {
            await prefs.setString(key, value);
          } else if (value is List) {
            await prefs.setString(key, jsonEncode(value));
          }
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        }
      }

      await prefs.setInt('launchCount', currentLaunchCount);

      final bool newIsDarkMode =
          allData['isDarkMode'] as bool? ?? widget.isDarkMode;
      widget.onThemeChanged(newIsDarkMode);


      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  void _confirmResetData() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Data'),
        content: const Text(
          'Are you sure you want to reset all activities, logs, and goals? This action cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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
    final uri = Uri(
        scheme: 'mailto',
        path: 'lockintrackerapp@gmail.com',
        queryParameters: {
          'subject': subject,
          if (body.isNotEmpty) 'body': body,
        });
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(
            const ClipboardData(text: 'lockintrackerapp@gmail.com'));
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
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
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
            child: Text('Data & Privacy',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
            child: Text('Support',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Backup & Restore',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Export Data'),
            subtitle: const Text('Share or save a backup file'),
            trailing: const Icon(Icons.upload_file, color: Colors.blue),
            onTap: _exportData,
          ),
          ListTile(
            title: const Text('Import Data'),
            subtitle: const Text('Restore from a backup file'),
            trailing: const Icon(Icons.download, color: Colors.green),
            onTap: _importData,
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