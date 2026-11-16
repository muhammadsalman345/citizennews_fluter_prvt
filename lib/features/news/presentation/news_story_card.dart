import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/news_models.dart';

class NewsStoryCard extends StatelessWidget {
  const NewsStoryCard({required this.story, super.key});

  final NewsSummary story;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.go('/news/${story.slug}'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 650;
          final image = story.imageUrl?.isNotEmpty == true
              ? Image.network(
                  story.imageUrl!,
                  height: wide ? 220 : 190,
                  width: wide ? 300 : double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(wide),
                )
              : _fallback(wide);
          final content = Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    Text(
                      story.category.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                    if (story.breaking)
                      const Text(
                        'BREAKING',
                        style: TextStyle(
                          color: AppColors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    if (story.corrected)
                      const Text(
                        'CORRECTED',
                        style: TextStyle(
                          color: AppColors.focus,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  story.headline,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 7),
                Text(
                  story.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(
                  '${story.fullName}${story.verified ? ' - verified' : ''} - ${story.city}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${story.views} views  ${story.likes} likes  ${story.comments} comments',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
          return wide
              ? Row(
                  children: [
                    SizedBox(width: 300, child: image),
                    Expanded(child: content),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [image, content],
                );
        },
      ),
    ),
  );

  Widget _fallback(bool wide) => Container(
    color: AppColors.surface,
    height: wide ? 220 : 190,
    width: wide ? 300 : double.infinity,
    alignment: Alignment.center,
    child: const Icon(Icons.newspaper_rounded, size: 44),
  );
}
