import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/ads/ads_scope.dart';
import '../../../core/localization/app_localizations.dart';
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
                  const Text(
                    'CITIZENNEWS POLICY',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    document.title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
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
                      onPressed: () => context.go('/'),
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
