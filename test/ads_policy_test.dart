import 'package:citizennews_flutter/core/ads/ads_policy.dart';
import 'package:citizennews_flutter/features/news/domain/news_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inline ads are available only on approved routes', () {
    expect(AdsPolicy.canShowInlineAdsOnRoute('/'), isTrue);
    expect(AdsPolicy.canShowInlineAdsOnRoute('/news/local-update'), isTrue);
    expect(AdsPolicy.canShowInlineAdsOnRoute('/messages'), isTrue);
    expect(AdsPolicy.canShowInlineAdsOnRoute('/messages/member-id'), isFalse);
    expect(AdsPolicy.canShowInlineAdsOnRoute('/account'), isFalse);
    expect(AdsPolicy.canShowInlineAdsOnRoute('/news/'), isFalse);
  });

  test('native feed and chat ads are placed after every third item', () {
    final stories = List<NewsSummary>.generate(
      8,
      (index) => NewsSummary(
        id: '$index',
        slug: 'story-$index',
        headline: 'Story $index',
        summary: 'Summary',
        reporterId: 'reporter',
        fullName: 'Reporter',
        username: 'reporter',
        city: 'City',
        category: 'Community',
        categorySlug: 'community',
        publishedAt: DateTime.utc(2026),
        likes: 0,
        dislikes: 0,
        comments: 0,
        views: 0,
        verified: true,
        breaking: false,
        status: 'published',
      ),
    );
    for (var index = 0; index < 8; index++) {
      final expected = index == 2 || index == 5;
      expect(AdsPolicy.canShowNativeAfter(stories, index), expected);
      expect(AdsPolicy.canShowNativeAfterChatUser(index), expected);
    }
  });

  test('article ads require a safe published story', () {
    final story = NewsSummary(
      id: '1',
      slug: 'local-update',
      headline: 'Local update',
      summary: 'Summary',
      reporterId: 'reporter',
      fullName: 'Reporter',
      username: 'reporter',
      city: 'City',
      category: 'Technology',
      categorySlug: 'technology',
      publishedAt: DateTime.utc(2026),
      likes: 0,
      dislikes: 0,
      comments: 0,
      views: 0,
      verified: true,
      breaking: false,
      status: 'published',
    );

    expect(AdsPolicy.isAdSafeStory(story), isTrue);
    expect(
      AdsPolicy.isAdSafeStory(story.copyWithForTest(breaking: true)),
      isFalse,
    );
  });
}

extension on NewsSummary {
  NewsSummary copyWithForTest({required bool breaking}) => NewsSummary(
    id: id,
    slug: slug,
    headline: headline,
    summary: summary,
    reporterId: reporterId,
    fullName: fullName,
    username: username,
    city: city,
    category: category,
    categorySlug: categorySlug,
    publishedAt: publishedAt,
    likes: likes,
    dislikes: dislikes,
    comments: comments,
    views: views,
    verified: verified,
    breaking: breaking,
    status: status,
  );
}
