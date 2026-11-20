import '../../features/news/domain/news_models.dart';
import '../../features/reporter/domain/public_reporter.dart';
import '../config/app_config.dart';
import 'seo_metadata.dart';

String _absolute(String path) {
  final base = AppConfig.webBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  if (path.startsWith('https://') || path.startsWith('http://')) return path;
  return '$base${path.startsWith('/') ? path : '/$path'}';
}

SeoMetadata articleSeo(NewsArticle article) {
  final story = article.summary;
  final path = '/news/${Uri.encodeComponent(story.slug)}';
  final url = _absolute(path);
  final images = article.images.isNotEmpty
      ? article.images.map(_absolute).toList(growable: false)
      : story.imageUrl?.isNotEmpty == true
      ? [_absolute(story.imageUrl!)]
      : [_absolute('/images/citizennews-og-default.png')];
  final reporterPath = story.username.isEmpty
      ? null
      : '/reporter/${Uri.encodeComponent(story.username)}';
  final description = story.summary.trim().isNotEmpty
      ? story.summary.trim()
      : 'Read this verified local report on CitizenNews.';

  return SeoMetadata(
    title: story.headline,
    description: description,
    path: path,
    type: 'article',
    imageUrl: images.first,
    imageAlt: story.headline,
    author: story.fullName,
    publishedAt: story.publishedAt,
    modifiedAt: article.updatedAt,
    structuredData: [
      {
        '@context': 'https://schema.org',
        '@type': 'NewsArticle',
        '@id': '$url#article',
        'mainEntityOfPage': {'@type': 'WebPage', '@id': url},
        'url': url,
        'headline': story.headline,
        'description': description,
        'image': images,
        if (story.publishedAt != null)
          'datePublished': story.publishedAt!.toUtc().toIso8601String(),
        if (article.updatedAt != null)
          'dateModified': article.updatedAt!.toUtc().toIso8601String(),
        'author': {
          '@type': 'Person',
          'name': story.fullName,
          if (reporterPath != null) 'url': _absolute(reporterPath),
        },
        'publisher': {
          '@type': 'Organization',
          'name': 'CitizenNews',
          'url': '${AppConfig.webBaseUrl}/',
          'logo': {
            '@type': 'ImageObject',
            'url': _absolute('/icons/Icon-512.png'),
          },
        },
        if (story.category.isNotEmpty) 'articleSection': story.category,
        if (story.city.isNotEmpty)
          'contentLocation': {'@type': 'City', 'name': story.city},
        'isAccessibleForFree': true,
      },
    ],
  );
}

SeoMetadata reporterSeo(PublicReporterData data) {
  final reporter = data.reporter;
  final path = '/reporter/${Uri.encodeComponent(reporter.username)}';
  final url = _absolute(path);
  final description = reporter.bio.trim().isNotEmpty
      ? reporter.bio.trim()
      : 'Read verified local reports published by ${reporter.fullName} on CitizenNews.';
  return SeoMetadata(
    title: '${reporter.fullName} (@${reporter.username})',
    description: description,
    path: path,
    type: 'profile',
    imageUrl: reporter.avatarUrl,
    imageAlt: '${reporter.fullName} on CitizenNews',
    author: reporter.fullName,
    structuredData: [
      {
        '@context': 'https://schema.org',
        '@type': 'ProfilePage',
        '@id': '$url#profile',
        'url': url,
        'name': '${reporter.fullName} on CitizenNews',
        'description': description,
        'mainEntity': {
          '@type': 'Person',
          'name': reporter.fullName,
          'alternateName': '@${reporter.username}',
          'url': url,
          if (reporter.avatarUrl?.isNotEmpty == true)
            'image': reporter.avatarUrl,
          if (reporter.cityName?.isNotEmpty == true)
            'homeLocation': {
              '@type': 'Place',
              'name': reporter.cityName,
            },
        },
      },
    ],
  );
}

SeoMetadata scopedFeedSeo({
  required String title,
  required String description,
  required String path,
}) => SeoMetadata(
  title: title,
  description: description,
  path: path,
  structuredData: [
    {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      'name': title,
      'description': description,
      'url': _absolute(path),
      'isPartOf': {
        '@type': 'WebSite',
        'name': 'CitizenNews',
        'url': '${AppConfig.webBaseUrl}/',
      },
    },
  ],
);

SeoMetadata noIndexSeo(String path, {String title = 'Content unavailable'}) =>
    SeoMetadata(
      title: title,
      description: 'This CitizenNews content is not available.',
      path: path,
      robots: SeoMetadata.noIndexRobots,
    );
