import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/news_models.dart';

class NewsStoryCard extends StatelessWidget {
  const NewsStoryCard({
    required this.story,
    this.reaction = 0,
    this.saved = false,
    this.busy = false,
    this.likeCount,
    this.dislikeCount,
    this.onLike,
    this.onDislike,
    this.onComment,
    this.onSave,
    this.onShare,
    super.key,
  });

  final NewsSummary story;
  final int reaction;
  final bool saved;
  final bool busy;
  final int? likeCount;
  final int? dislikeCount;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onComment;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  void _open(BuildContext context) => context.push('/news/${story.slug}');

  @override
  Widget build(BuildContext context) {
    final likes = likeCount ?? story.likes;
    final dislikes = dislikeCount ?? story.dislikes;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StoryHeader(story: story, onShare: onShare),
          InkWell(
            onTap: () => _open(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (story.imageUrl?.isNotEmpty == true)
                  _StoryImage(url: story.imageUrl!, breaking: story.breaking)
                else
                  _StoryImageFallback(breaking: story.breaking),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _StoryTag(
                            label: story.category.toUpperCase(),
                            color: AppColors.red,
                          ),
                          if (story.corrected)
                            const _StoryTag(
                              label: 'CORRECTED',
                              color: AppColors.focus,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        story.headline,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 21,
                          height: 1.22,
                          letterSpacing: -.35,
                        ),
                      ),
                      if (story.summary.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          story.summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                            height: 1.48,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _location(story),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${_compact(story.views)} views',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: _StoryAction(
                    icon: reaction == 1
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                    label: _compact(likes),
                    selected: reaction == 1,
                    onTap: busy ? null : (onLike ?? () => _open(context)),
                  ),
                ),
                Expanded(
                  child: _StoryAction(
                    icon: reaction == -1
                        ? Icons.thumb_down_rounded
                        : Icons.thumb_down_outlined,
                    label: _compact(dislikes),
                    selected: reaction == -1,
                    onTap: busy ? null : (onDislike ?? () => _open(context)),
                  ),
                ),
                Expanded(
                  child: _StoryAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: _compact(story.comments),
                    onTap: onComment ?? () => _open(context),
                  ),
                ),
                if (onSave != null)
                  Expanded(
                    child: _StoryAction(
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: saved ? 'Saved' : 'Save',
                      selected: saved,
                      onTap: busy ? null : onSave,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({required this.story, this.onShare});

  final NewsSummary story;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 13, 8, 12),
    child: Row(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: story.username.isEmpty
              ? null
              : () => context.push(
                  '/reporter/${Uri.encodeComponent(story.username)}',
                ),
          child: CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.surface,
            backgroundImage: story.avatarUrl?.isNotEmpty == true
                ? NetworkImage(story.avatarUrl!)
                : null,
            child: story.avatarUrl?.isNotEmpty == true
                ? null
                : Text(
                    _initial(story.fullName),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      story.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (story.verified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: AppColors.focus,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (story.username.isNotEmpty) '@${story.username}',
                  _relativeTime(story.publishedAt),
                ].where((value) => value.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (onShare != null)
          IconButton(
            tooltip: 'Share story',
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded, size: 20),
          ),
      ],
    ),
  );
}

class _StoryImage extends StatelessWidget {
  const _StoryImage({required this.url, required this.breaking});

  final String url;
  final bool breaking;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const _StoryImageFallback(breaking: false),
        ),
        if (breaking)
          const Positioned(left: 12, top: 12, child: _BreakingBadge()),
      ],
    ),
  );
}

class _StoryImageFallback extends StatelessWidget {
  const _StoryImageFallback({required this.breaking});

  final bool breaking;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ColoredBox(
      color: AppColors.surface,
      child: Stack(
        children: [
          const Center(
            child: Icon(
              Icons.newspaper_rounded,
              size: 52,
              color: AppColors.muted,
            ),
          ),
          if (breaking)
            const Positioned(left: 12, top: 12, child: _BreakingBadge()),
        ],
      ),
    ),
  );
}

class _BreakingBadge extends StatelessWidget {
  const _BreakingBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.red,
      borderRadius: BorderRadius.circular(999),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
        SizedBox(width: 3),
        Text(
          'BREAKING',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ],
    ),
  );
}

class _StoryTag extends StatelessWidget {
  const _StoryTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .35,
      ),
    ),
  );
}

class _StoryAction extends StatelessWidget {
  const _StoryAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: selected ? AppColors.red : AppColors.muted,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
      minimumSize: const Size(0, 42),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    icon: Icon(icon, size: 19),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

String _location(NewsSummary story) => [
  story.city,
  if (story.region?.isNotEmpty == true) story.region!,
  if (story.country?.isNotEmpty == true) story.country!,
].where((value) => value.trim().isNotEmpty).join(', ');

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'C' : trimmed[0].toUpperCase();
}

String _compact(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  }
  return '$value';
}

String _relativeTime(DateTime? value) {
  if (value == null) return '';
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
