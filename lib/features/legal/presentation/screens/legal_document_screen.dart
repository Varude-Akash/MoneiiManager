import 'package:flutter/material.dart';
import 'package:moneii_manager/config/theme.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
    required this.lastUpdated,
  });

  final String title;
  final List<LegalSection> sections;
  final String lastUpdated;

  static LegalDocumentScreen privacyPolicy({Key? key}) {
    return LegalDocumentScreen(
      key: key,
      title: 'Privacy Policy',
      lastUpdated: 'February 24, 2026',
      sections: const [
        LegalSection(
          heading: 'What We Collect',
          body:
              'We collect account information (email), profile settings, financial entries '
              '(income, expenses, transfers), and app usage required to provide the service.',
        ),
        LegalSection(
          heading: 'Voice and AI Data',
          body:
              'Voice recordings are processed to generate transaction text. AI prompts use your '
              'own app data to answer your questions. Do not share sensitive credentials in prompts.',
        ),
        LegalSection(
          heading: 'How We Use Data',
          body:
              'We use data to provide core app features, analytics, premium features, and account support.',
        ),
        LegalSection(
          heading: 'Data Storage',
          body:
              'Data is stored in Supabase. Access is restricted by authentication and row-level security.',
        ),
        LegalSection(
          heading: 'Account Deletion',
          body:
              'You can delete your account inside the app from Profile > Delete Account. '
              'Deletion removes your authentication account and associated app data.',
        ),
        LegalSection(
          heading: 'Contact',
          body: 'For privacy requests, contact support using the email listed in the store listing.',
        ),
      ],
    );
  }

  static LegalDocumentScreen termsOfService({Key? key}) {
    return LegalDocumentScreen(
      key: key,
      title: 'Terms of Service',
      lastUpdated: 'February 24, 2026',
      sections: const [
        LegalSection(
          heading: 'Service Use',
          body:
              'MoneiiManager is a personal finance tool. You are responsible for your own financial decisions.',
        ),
        LegalSection(
          heading: 'Accounts',
          body:
              'You must provide accurate account information and keep your credentials secure.',
        ),
        LegalSection(
          heading: 'Premium Features',
          body:
              'Premium and Premium Plus features may include usage limits. Limits and pricing can change.',
        ),
        LegalSection(
          heading: 'AI Responses',
          body:
              'AI outputs are for informational use and may contain mistakes. They are not legal, tax, '
              'or investment advice.',
        ),
        LegalSection(
          heading: 'Termination',
          body:
              'You may stop using the service at any time. You can permanently delete your account in-app.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Last updated: $lastUpdated',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.heading,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    section.body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}
