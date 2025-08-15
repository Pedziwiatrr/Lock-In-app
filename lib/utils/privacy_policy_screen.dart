import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _privacyPolicyHtml = '''
    <h1>Privacy Policy for Lock-In Tracker</h1>
    <p><strong>Last Updated: August 15, 2025</strong></p>
    
    <p>Thank you for using Lock-In Tracker. This Privacy Policy explains what information we process and why.</p>
    
    <h2>1. Data Controller</h2>
    <p>
        The administrator of your data is:<br>
        <strong>Pedziwiatr</strong><br>
        Contact Email: <strong>lockintrackerapp@gmail.com</strong><br>
    </p>
    
    <h2>2. What Information Do We Process?</h2>
    <p>This application was designed with your privacy in mind. We divide data into three categories:</p>
    
    <h4>a) Data You Create in the App</h4>
    <p>
        This is all the information you enter directly into the application, such as:
        <ul>
            <li>The names of your Activities</li>
            <li>The definitions of your Goals</li>
            <li>Saved logs (dates, durations, and completions of activities)</li>
        </ul>
        <strong>Important:</strong> All of this data is stored and processed <strong>exclusively locally on your device</strong>. We, as the developers of the application, do not have access to it.
    </p>
    
    <h4>b) Data Collected Automatically by Partners</h4>
    <p>
        To display advertisements, we use the Google AdMob service. Google may collect anonymous data to personalize ads (if you have given your consent) and for analytical purposes. This may include:
        <ul>
            <li>Device advertising identifier (IDFA/AAID)</li>
            <li>IP address</li>
            <li>Device and operating system information</li>
            <li>Diagnostic and crash data</li>
        </ul>
        You can find more information in Google's Privacy Policy: <a href="https://policies.google.com/privacy">https://policies.google.com/privacy</a>
    </p>

    <h4>c) Local Notifications</h4>
    <p>
        The application uses local notifications to help you stay on track with your goals. This includes:
        <ul>
            <li>Daily reminders about your goals.</li>
            <li>An ongoing notification to show the status of an active timer.</li>
        </ul>
        <strong>Important:</strong> All processing related to scheduling and displaying these notifications happens <strong>exclusively locally on your device</strong>. We do not send any data to external servers for this purpose, and we do not have access to the content of your notifications.
    </p>
    
    <h2>3. Your Rights and Control Over Data</h2>
    <p>
        You have full control over your data. Since it is stored only on your phone, you can delete it at any time in two ways:
        <ol>
            <li>By using the "Reset Data" feature in the app's Settings.</li>
            <li>By uninstalling the application from your device.</li>
        </ol>
    </p>
    <p>
        Additionally, you have full control over notifications. You can enable or disable them at any time from within the application's Settings screen or through your device's system settings.
    </p>
    
    <h2>4. Children's Policy</h2>
    <p>The application is not intended for children under the age of 16. We do not knowingly collect any data from minors.</p>
    
    <h2>5. Contact Us</h2>
    <p>
        If you have any questions regarding this policy, please contact us at: 
        <a href="mailto:lockintrackerapp@gmail.com">lockintrackerapp@gmail.com</a>.
    </p>
  ''';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Privacy Policy'),
        ),
        body: SingleChildScrollView(
          child: Html(
            data: _privacyPolicyHtml,
            style: {
              'body': Style(
                fontSize: FontSize(16),
                padding: HtmlPaddings.all(16),
              ),
              'h1': Style(fontSize: FontSize(24), fontWeight: FontWeight.bold),
              'h2': Style(fontSize: FontSize(20), fontWeight: FontWeight.bold, margin: Margins.only(top: 16)),
              'h4': Style(fontSize: FontSize(16), fontWeight: FontWeight.bold, margin: Margins.only(top: 12)),
              'p': Style(lineHeight: const LineHeight(1.5)),
              'a': Style(color: Colors.blue, textDecoration: TextDecoration.none),
            },
            onLinkTap: (url, attributes, element) async {
              if (url != null) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
        ),
      ),
    );
  }
}