class ReporterStats {
  const ReporterStats({required this.name, required this.username, required this.points, required this.published, required this.followers, required this.views, required this.likes, required this.rating, required this.trust, this.rank});
  final String name, username;
  final num points, published, followers, views, likes, rating, trust;
  final int? rank;
  factory ReporterStats.fromJson(Map<String, dynamic> j) => ReporterStats(name: j['full_name'] as String? ?? '', username: j['username'] as String? ?? '', points: j['points'] as num? ?? 0, published: j['published'] as num? ?? 0, followers: j['followers'] as num? ?? 0, views: j['views'] as num? ?? 0, likes: j['likes'] as num? ?? 0, rating: j['rating'] as num? ?? 0, trust: j['trust_score'] as num? ?? 0, rank: (j['rank'] as num?)?.toInt());
}
class Performance {
  const Performance({required this.pending, required this.changes, required this.rejected, required this.views, required this.uniqueViews, required this.likes, required this.dislikes, required this.comments, required this.daily});
  final num pending, changes, rejected, views, uniqueViews, likes, dislikes, comments;
  final List<DailyViews> daily;
  factory Performance.fromJson(Map<String, dynamic> j) => Performance(pending: j['pending'] as num? ?? 0, changes: j['changes_requested'] as num? ?? 0, rejected: j['rejected'] as num? ?? 0, views: j['views'] as num? ?? 0, uniqueViews: j['unique_views'] as num? ?? 0, likes: j['likes'] as num? ?? 0, dislikes: j['dislikes'] as num? ?? 0, comments: j['comments'] as num? ?? 0, daily: (j['daily'] as List? ?? const []).whereType<Map>().map((x) => DailyViews.fromJson(Map<String,dynamic>.from(x))).toList());
}
class DailyViews { const DailyViews(this.day, this.views); final String day; final num views; factory DailyViews.fromJson(Map<String,dynamic> j) => DailyViews(j['day'] as String? ?? '', j['views'] as num? ?? 0); }
class WalletSummary {
  const WalletSummary({required this.currency, required this.available, required this.pending, required this.reserved, required this.withdrawn, required this.minimum});
  final String currency; final num available, pending, reserved, withdrawn, minimum;
  factory WalletSummary.fromJson(Map<String,dynamic> j) => WalletSummary(currency: j['currency'] as String? ?? '', available: j['available'] as num? ?? 0, pending: j['pending'] as num? ?? 0, reserved: j['reserved'] as num? ?? 0, withdrawn: j['withdrawn'] as num? ?? 0, minimum: j['minimum_withdrawal'] as num? ?? 100);
}
class EconomyEntry {
  const EconomyEntry({required this.id, required this.amount, required this.label, required this.createdAt, this.status = '', this.currency = ''});
  final String id, label, status, currency, createdAt; final num amount;
  factory EconomyEntry.points(Map<String,dynamic> j) => EconomyEntry(id: j['id'].toString(), amount: j['points'] as num? ?? 0, label: j['reason'] as String? ?? j['event'] as String? ?? 'Points', createdAt: j['created_at'] as String? ?? '');
  factory EconomyEntry.transaction(Map<String,dynamic> j) => EconomyEntry(id: j['id'].toString(), amount: j['amount'] as num? ?? 0, label: j['reason'] as String? ?? j['kind'] as String? ?? 'Wallet transaction', currency: j['currency'] as String? ?? '', createdAt: j['created_at'] as String? ?? '');
  factory EconomyEntry.withdrawal(Map<String,dynamic> j) => EconomyEntry(id: j['id'].toString(), amount: j['amount'] as num? ?? 0, label: j['payout_method'] as String? ?? 'Withdrawal', status: j['status'] as String? ?? '', currency: j['currency'] as String? ?? '', createdAt: j['created_at'] as String? ?? '');
}
class ReporterEconomyData {
  const ReporterEconomyData({this.stats, this.performance, this.wallet, this.points = const [], this.transactions = const [], this.withdrawals = const []});
  final ReporterStats? stats; final Performance? performance; final WalletSummary? wallet; final List<EconomyEntry> points, transactions, withdrawals;
}
