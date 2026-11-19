import '../../features/news/domain/news_models.dart';

abstract final class AdsPolicy {
  static const interstitialCooldown = Duration(minutes: 15);
  static const interstitialDailyLimit = 2;
  static const articlesBetweenInterstitials = 3;
  static const qualifyingReadTime = Duration(seconds: 30);
  static const rewardedAdFreeTime = Duration(minutes: 30);
  static const appOpenMinimumSessions = 3;
  static const appOpenMinimumBackground = Duration(minutes: 2);
  static const appOpenCooldown = Duration(hours: 8);
  static const appOpenDailyLimit = 1;
  static const appOpenMaxCache = Duration(hours: 4);
  static const nativeAfterStories = 3;
  static const nativeAfterChatUsers = 3;

  static const _publicRoutes = {
    '/',
    '/latest',
    '/trending',
    '/explore',
    '/search',
    '/world',
    '/reporters',
  };

  static final _publicPatterns = <RegExp>[
    RegExp(r'^/region/[^/]+/[^/]+$'),
    RegExp(r'^/city/[^/]+/[^/]+$'),
    RegExp(r'^/country/[^/]+$'),
    RegExp(r'^/category/[^/]+$'),
    RegExp(r'^/reporter/[^/]+$'),
  ];

  static final _safeCategory = RegExp(
    r'^(traffic|weather|education|politics|community|events|business|technology|tech|sports|science|culture|travel|lifestyle|jobs(?:-[a-z0-9-]+)?)$',
    caseSensitive: false,
  );

  static bool isPublicDiscoveryRoute(String path) =>
      _publicRoutes.contains(path) ||
      _publicPatterns.any((pattern) => pattern.hasMatch(path));

  static bool isArticleRoute(String path) =>
      RegExp(r'^/news/[^/]+$').hasMatch(path);

  static bool isChatInboxRoute(String path) => path == '/messages';

  static bool canShowInlineAdsOnRoute(String path) =>
      isPublicDiscoveryRoute(path) ||
      isArticleRoute(path) ||
      isChatInboxRoute(path);

  static bool isAdSafeStory(NewsSummary story) =>
      const {'published', 'corrected'}.contains(story.status) &&
      !story.breaking &&
      story.riskFlags.isEmpty &&
      _safeCategory.hasMatch(story.categorySlug ?? '');

  static bool canShowNativeAfter(List<NewsSummary> stories, int index) {
    return index >= 0 &&
        index < stories.length &&
        (index + 1) % nativeAfterStories == 0;
  }

  static bool canShowNativeAfterChatUser(int index) =>
      index >= 0 && (index + 1) % nativeAfterChatUsers == 0;

  /// Places one reliable inline banner near the top of a public feed while
  /// keeping it away from breaking or otherwise ad-sensitive stories.
  static bool canShowBannerAfter(List<NewsSummary> stories, int index) {
    if (index < 0 || index >= stories.length || index > 2) return false;
    if (!isAdSafeStory(stories[index])) return false;
    for (var previous = 0; previous < index; previous++) {
      if (isAdSafeStory(stories[previous])) return false;
    }
    return true;
  }
}
