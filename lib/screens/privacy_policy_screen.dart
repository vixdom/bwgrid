import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BollyWord Grid Privacy Policy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Last updated: January 2024',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                'Information We Collect',
                'We collect information about you in the following ways:\n\n'
                '• Device Information: We may collect information about your device, including device type, operating system, and unique device identifiers.\n\n'
                '• Usage Data: We collect information about how you use our app, including gameplay statistics and preferences.\n\n'
                '• Advertising Data: Our app uses Google AdMob to display advertisements. AdMob may collect information about your device and usage patterns to provide relevant ads.',
              ),
              _buildSection(
                'How We Use Your Information',
                'We use the collected information to:\n\n'
                '• Provide and maintain our word search game\n'
                '• Display relevant advertisements\n'
                '• Improve our app and develop new features\n'
                '• Analyze usage patterns and app performance',
              ),
              _buildSection(
                'Third-Party Services',
                'Our app uses the following third-party services:\n\n'
                '• Google AdMob: For displaying advertisements\n'
                '• Game Center (iOS): For achievements and leaderboards\n'
                '• Google Play Games (Android): For achievements and leaderboards\n'
                '• Shared Preferences: For storing your game settings locally on your device',
              ),
              _buildSection(
                'Data Sharing',
                'We do not sell, trade, or otherwise transfer your personal information to third parties, except as described in this policy:\n\n'
                '• Advertising partners may receive anonymized data to provide relevant ads\n'
                '• Game services (Game Center/Play Games) may store your achievements and scores on their servers',
              ),
              _buildSection(
                'Data Storage',
                '• Game progress and settings are stored locally on your device\n'
                '• Achievements and scores may be stored on Apple Game Center or Google Play Games servers\n'
                '• We do not store personal data on our own servers',
              ),
              _buildSection(
                'Your Rights',
                'You have the right to:\n\n'
                '• Access the personal information we have about you\n'
                '• Request deletion of your data\n'
                '• Opt out of personalized advertising through your device settings\n'
                '• Disable game services integration in the app settings',
              ),
              _buildSection(
                'Children\'s Privacy',
                'Our app is not intended for children under 13. We do not knowingly collect personal information from children under 13.',
              ),
              _buildSection(
                'Changes to This Policy',
                'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page.',
              ),
              _buildSection(
                'Contact Us',
                'If you have any questions about this privacy policy, please contact us at:\n\n'
                'support@bollyword.com',
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    const url = 'https://policies.google.com/privacy';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    }
                  },
                  child: const Text('View Google Privacy Policy'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}