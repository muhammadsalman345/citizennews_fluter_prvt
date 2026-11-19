import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/ads/ads_scope.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/legal_content.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.page, super.key});

  final String page;

  @override
  Widget build(BuildContext context) {
    final document = legalDocuments[page] ?? legalDocuments['about']!;
    final ads = AdsScope.watch(context);
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: SelectionArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 18 : 32,
                  mobile ? 24 : 42,
                  mobile ? 18 : 32,
                  90,
                ),
                children: [
                  _LegalHeader(title: document.title, page: page),
                  const SizedBox(height: 22),
                  for (final section in document.sections)
                    _LegalSectionCard(section: section),
                  if (page == 'privacy' && ads.privacyRequired) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: ads.showPrivacyOptions,
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('Ad privacy choices'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  const LegalRelatedLinks(),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.backOr('/'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(context.tr('legal.back')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalHeader extends StatelessWidget {
  const _LegalHeader({required this.title, required this.page});

  final String title;
  final String page;

  IconData get _icon => switch (page) {
        'privacy' => Icons.privacy_tip_outlined,
        'terms' => Icons.gavel_outlined,
        'community-guidelines' => Icons.groups_outlined,
        'editorial-policy' => Icons.fact_check_outlined,
        'corrections-policy' => Icons.history_edu_outlined,
        'copyright' => Icons.copyright_rounded,
        'content-removal' => Icons.policy_outlined,
        _ => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101826), Color(0xFF26374D)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_icon, color: Colors.white, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CITIZENNEWS POLICY',
                    style: TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Clear standards for a safe, transparent and accountable news community.',
                    style: TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 13),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 9),
          Text(
            section.text,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    ),
  );
}

class LegalRelatedLinks extends StatelessWidget {
  const LegalRelatedLinks({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('legal.related'),
    child: Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        OutlinedButton(
          onPressed: () => context.go('/contact'),
          child: Text(context.tr('legal.contact')),
        ),
        OutlinedButton(
          onPressed: () => context.go('/privacy'),
          child: Text(context.tr('legal.privacy')),
        ),
        OutlinedButton(
          onPressed: () => context.go('/terms'),
          child: Text(context.tr('legal.terms')),
        ),
        OutlinedButton(
          onPressed: () => context.go('/community-guidelines'),
          child: Text(context.tr('legal.community')),
        ),
      ],
    ),
  );
}
