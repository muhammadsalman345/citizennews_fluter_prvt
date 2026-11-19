import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/theme/app_colors.dart';

class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 42,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppColors.red, size: 38),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      eyebrow,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('Go to home'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.backOr('/'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Go back'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
