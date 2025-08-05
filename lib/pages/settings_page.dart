import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/privacy_policy_screen.dart';
import '../utils/ad_manager.dart';

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
  bool? _personalizedAdsConsent;
  bool _consentLoaded = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _personalizedAdsConsent = prefs.getBool('personalizedAdsConsent') ?? false;
      _consentLoaded = true;
    });
  }

  Future<void> _showConsentForm() async {
    final prefs = await SharedPreferences.getInstance();
    ConsentInformation.instance.reset();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(
        consentDebugSettings: ConsentDebugSettings(
          debugGeography: DebugGeography.debugGeographyEea,
        ),
      ),
          () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          print('[DEBUG] Consent form available and required, loading form');
          ConsentForm.loadConsentForm(
                (ConsentForm consentForm) async {
              consentForm.show(
                    (FormError? error) async {
                  if (error != null) {
                    print('[DEBUG] Consent form error: ${error.message}');
                    await prefs.setBool('personalizedAdsConsent', false);
                    setState(() {
                      _personalizedAdsConsent = false;
                    });
                    await AdManager.initialize();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to process consent')),
                      );
                    }
                  } else {
                    print('[DEBUG] Initializing consent form');
                    final status = await ConsentInformation.instance.getConsentStatus();
                    final canRequest = await ConsentInformation.instance.canRequestAds();
                    bool personalizedAds = status == ConsentStatus.obtained && canRequest;

                    if (personalizedAds) {
                      final requestConfig = await MobileAds.instance.getRequestConfiguration();
                      personalizedAds = requestConfig.tagForChildDirectedTreatment == null &&
                          requestConfig.tagForUnderAgeOfConsent == null &&
                          requestConfig.maxAdContentRating == null;
                    }

                    await prefs.setBool('personalizedAdsConsent', personalizedAds);
                    setState(() {
                      _personalizedAdsConsent = personalizedAds;
                    });
                    await AdManager.initialize();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            personalizedAds
                                ? 'Personalized ads enabled'
                                : 'Personalized ads disabled',
                          ),
                        ),
                      );
                    }
                    print('[DEBUG] Consent initialized: personalizedAdsConsent=$personalizedAds');
                    print('[DEBUG] Consent status after form: $status, Can request ads: $canRequest');
                  }
                },
              );
            },
                (FormError loadError) async {
              print('[DEBUG] Load consent form error: ${loadError.message}');
              await prefs.setBool('personalizedAdsConsent', false);
              setState(() {
                _personalizedAdsConsent = false;
              });
              await AdManager.initialize();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to load consent form')),
                );
              }
            },
          );
        } else {
          print('[DEBUG] Consent form not available or not required');
          bool personalizedAds = (await ConsentInformation.instance.getConsentStatus()) == ConsentStatus.obtained;
          if (personalizedAds) {
            final requestConfig = await MobileAds.instance.getRequestConfiguration();
            personalizedAds = requestConfig.tagForChildDirectedTreatment == null &&
                requestConfig.tagForUnderAgeOfConsent == null &&
                requestConfig.maxAdContentRating == null;
          }
          await prefs.setBool('personalizedAdsConsent', personalizedAds);
          setState(() {
            _personalizedAdsConsent = personalizedAds;
          });
          await AdManager.initialize();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  personalizedAds
                      ? 'Personalized ads enabled'
                      : 'Personalized ads disabled',
                ),
              ),
            );
          }
          print('[DEBUG] Personalized ads set to: $personalizedAds');
        }
      },
          (FormError updateError) async {
        print('[DEBUG] Consent info update error: ${updateError.message}');
        await prefs.setBool('personalizedAdsConsent', false);
        setState(() {
          _personalizedAdsConsent = false;
        });
        await AdManager.initialize();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update consent info')),
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
          'Are you sure you want to reset all activities, logs, and goals? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              widget.onResetData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data has been reset.')),
              );
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ListTile(
            title: const Text('Personalized Ads'),
            subtitle: Text(
              !_consentLoaded
                  ? 'Loading...'
                  : (_personalizedAdsConsent! ? 'Enabled' : 'Disabled'),
            ),
            trailing: ElevatedButton(
              onPressed: !_consentLoaded ? null : _showConsentForm,
              child: const Text('Change ad settings'),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Privacy Policy'),
            subtitle: const Text('View our privacy policy.'),
            trailing: const Icon(Icons.privacy_tip, color: Colors.blue),
            onTap: _launchPrivacyPolicy,
          ),
          const Divider(),
          ListTile(
            title: const Text('Contact Us'),
            subtitle: const Text('Reach out to support.'),
            trailing: const Icon(Icons.email, color: Colors.blue),
            onTap: () => _launchEmail('Contact LockIn Tracker Support'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Report a Bug'),
            subtitle: const Text('Let us know about issues.'),
            trailing: const Icon(Icons.bug_report, color: Colors.orange),
            onTap: () => _launchEmail(
              'Bug Report',
              body: 'Describe bug:\n\nApp Version:\nDevice:\nOS:\nSteps:',
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset Data'),
            subtitle: const Text('Delete all activities, logs, and goals.'),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: _confirmResetData,
          ),
        ]),
      ),
    );
  }
}