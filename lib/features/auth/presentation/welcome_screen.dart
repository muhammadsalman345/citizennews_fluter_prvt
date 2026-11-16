import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    return SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.contentMax,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 20 : 40,
                mobile ? 42 : 70,
                mobile ? 20 : 40,
                80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WELCOME TO CITIZENNEWS',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: const [
                        TextSpan(text: 'Your city.\nYour stories.\n'),
                        TextSpan(
                          text: 'Your voice.',
                          style: TextStyle(color: AppColors.red),
                        ),
                      ],
                    ),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: mobile ? 58 : 82,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: const Text(
                      'Discover verified local reporting, share what is happening around you, and help your community stay informed.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 17,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/signup'),
                        child: const Text('Create your account'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Explore the news'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  const _FeatureGrid(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.my_location_rounded,
        'Local first',
        'Follow stories from the places that matter to you.',
      ),
      (
        Icons.verified_user_outlined,
        'Verified voices',
        'Reporter identity and evidence are reviewed before publication.',
      ),
      (
        Icons.people_alt_outlined,
        'Community powered',
        'React, discuss and hold local reporting accountable.',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth <= AppBreakpoints.mobile ? 1 : 3;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 44) / columns;
        return Wrap(
          spacing: 22,
          runSpacing: 16,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$1, color: AppColors.red, size: 35),
                          const SizedBox(height: 20),
                          Text(
                            item.$2,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.$3,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
