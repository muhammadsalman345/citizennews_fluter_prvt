import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import 'seo_metadata.dart';
import 'seo_service.dart';

class SeoRouteScope extends StatefulWidget {
  const SeoRouteScope({
    required this.location,
    required this.child,
    this.notFound = false,
    super.key,
  });

  final String location;
  final Widget child;
  final bool notFound;

  @override
  State<SeoRouteScope> createState() => _SeoRouteScopeState();
}

class _SeoRouteScopeState extends State<SeoRouteScope> {
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant SeoRouteScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.notFound != widget.notFound) {
      _schedule();
    }
  }

  void _schedule() => WidgetsBinding.instance.addPostFrameCallback((_) {
    SeoService.apply(_forLocation(widget.location, notFound: widget.notFound));
  });

  @override
  Widget build(BuildContext context) => widget.child;
}

SeoMetadata _forLocation(String location, {required bool notFound}) {
  final uri = Uri.tryParse(location) ?? Uri(path: '/');
  final path = uri.path.isEmpty ? '/' : uri.path;
  if (notFound) {
    return const SeoMetadata(
      title: 'Page not found',
      description: 'The requested CitizenNews page could not be found.',
      path: '/',
      robots: SeoMetadata.noIndexRobots,
    );
  }

  const privatePrefixes = [
    '/account', '/admin', '/analytics', '/appeals', '/comments', '/dashboard',
    '/following', '/forgot-password', '/login', '/messages', '/my-stories',
    '/otp', '/points', '/profile', '/report-news', '/reset-password', '/saved',
    '/search', '/settings', '/signup', '/verification', '/wallet', '/welcome',
  ];
  if (privatePrefixes.any(
    (prefix) => path == prefix || path.startsWith('$prefix/'),
  )) {
    return SeoMetadata(
      title: 'CitizenNews',
      description: 'Secure CitizenNews account page.',
      path: path,
      robots: SeoMetadata.noIndexRobots,
    );
  }

  final page = _publicPages[path];
  if (page != null) {
    return SeoMetadata(
      title: page.$1,
      description: page.$2,
      path: path,
      structuredData: path == '/'
          ? [
              {
                '@context': 'https://schema.org',
                '@type': 'WebSite',
                'name': 'CitizenNews',
                'url': '${AppConfig.webBaseUrl}/',
              },
              {
                '@context': 'https://schema.org',
                '@type': 'Organization',
                'name': 'CitizenNews',
                'url': '${AppConfig.webBaseUrl}/',
                'logo': '${AppConfig.webBaseUrl}/icons/Icon-512.png',
              },
            ]
          : const [],
    );
  }

  if (path.startsWith('/news/')) {
    return SeoMetadata(
      title: 'News story',
      description: 'Read this verified local report on CitizenNews.',
      path: path,
    );
  }
  if (path.startsWith('/reporter/')) {
    return SeoMetadata(
      title: 'Citizen reporter',
      description: 'View this reporter profile and published stories.',
      path: path,
    );
  }
  if (path.startsWith('/country/') ||
      path.startsWith('/region/') ||
      path.startsWith('/city/') ||
      path.startsWith('/category/')) {
    return SeoMetadata(
      title: 'Local news',
      description: 'Browse verified local stories and breaking news.',
      path: path,
    );
  }

  return SeoMetadata(
    title: 'Page not found',
    description: 'The requested CitizenNews page could not be found.',
    path: path,
    robots: SeoMetadata.noIndexRobots,
  );
}

const _publicPages = <String, (String, String)>{
  '/': (
    'CitizenNews | Verified Local News',
    'Discover verified local news, breaking stories and trusted citizen reporting from communities around the world.',
  ),
  '/latest': ('Latest News', 'Read the latest verified stories on CitizenNews.'),
  '/trending': ('Trending News', 'See the stories readers are following now.'),
  '/world': ('World News', 'Explore verified citizen reporting from around the world.'),
  '/explore': ('Explore Local News', 'Find news by country, region, city and category.'),
  '/reporters': ('Top Citizen Reporters', 'Discover trusted CitizenNews reporters and their stories.'),
  '/about': ('About CitizenNews', 'Learn how CitizenNews supports verified citizen reporting.'),
  '/contact': ('Contact CitizenNews', 'Contact the CitizenNews support and editorial teams.'),
  '/privacy': ('Privacy Policy', 'Read the CitizenNews privacy policy.'),
  '/terms': ('Terms of Service', 'Read the CitizenNews terms of service.'),
  '/community-guidelines': ('Community Guidelines', 'Read the CitizenNews community standards.'),
  '/editorial-policy': ('Editorial Policy', 'Read the CitizenNews editorial and verification policy.'),
  '/corrections-policy': ('Corrections Policy', 'Learn how CitizenNews corrects published reports.'),
  '/content-removal': ('Content Removal Policy', 'Read the CitizenNews content removal process.'),
  '/copyright': ('Copyright Policy', 'Read the CitizenNews copyright policy.'),
};
