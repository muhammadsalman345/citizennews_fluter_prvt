import 'package:supabase_flutter/supabase_flutter.dart';

import '../../location/data/location_repository.dart';
import '../../location/domain/location_models.dart';
import '../../news/data/news_repository.dart';
import '../../news/domain/news_models.dart';
import '../domain/public_reporter.dart';

class PublicReporterRepository {
  PublicReporterRepository(this.client)
    : news = NewsRepository(client),
      locations = LocationRepository(client);

  final SupabaseClient client;
  final NewsRepository news;
  final LocationRepository locations;

  Future<PublicReporterData?> load(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) return null;
    final row = await client
        .from('public_reporters')
        .select('id,full_name,username,city_id,avatar_url,bio')
        .eq('username', cleanUsername)
        .maybeSingle();
    if (row == null) return null;
    final reporterId = row['id'].toString();
    final cityId = row['city_id']?.toString();
    final results = await Future.wait<dynamic>([
      client
          .from('reporter_statistics')
          .select(
            'points,published,followers,views,likes,rating,trust_score',
          )
          .eq('user_id', reporterId)
          .maybeSingle(),
      client
          .from('public_news')
          .select('*')
          .eq('reporter_id', reporterId)
          .order('published_at', ascending: false),
      if (cityId?.isNotEmpty == true)
        locations.city(cityId!)
      else
        Future.value(null),
      news.isFollowing('reporter', reporterId),
    ]);
    final statsRow = results[0] as Map<String, dynamic>?;
    final stories = (results[1] as List)
        .whereType<Map>()
        .map((value) => NewsSummary.fromJson(Map<String, dynamic>.from(value)))
        .toList(growable: false);
    final city = results[2] as LocationRow?;
    return PublicReporterData(
      reporter: PublicReporter.fromJson(
        row,
        cityName: city?.name,
      ),
      stats: statsRow == null
          ? const PublicReporterStats(
              points: 0,
              published: 0,
              followers: 0,
              views: 0,
              likes: 0,
              rating: 0,
              trust: 0,
            )
          : PublicReporterStats.fromJson(statsRow),
      stories: stories,
      followed: results[3] == true,
    );
  }

  Future<void> setFollow(String reporterId, bool followed) =>
      news.setFollowing('reporter', reporterId, followed);
}
