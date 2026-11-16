import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/reporter_economy.dart';

class ReporterEconomyRepository {
  const ReporterEconomyRepository(this.client); final SupabaseClient client;
  Future<ReporterEconomyData> load(String mode, int days) async {
    final uid = client.auth.currentUser!.id;
    final statsRaw = await client.from('reporter_statistics').select().eq('user_id', uid).maybeSingle();
    Performance? performance; WalletSummary? wallet; List<EconomyEntry> points = const [], transactions = const [], withdrawals = const [];
    if (mode == 'dashboard') { final raw = await client.rpc<dynamic>('reporter_dashboard', params: {'days': days}); performance = Performance.fromJson(Map<String,dynamic>.from(raw as Map)); }
    if (mode == 'dashboard' || mode == 'wallet') {
      final summary = await client.rpc<dynamic>('my_wallet_summary'); wallet = WalletSummary.fromJson(Map<String,dynamic>.from(summary as Map));
      final t = await client.from('wallet_transactions').select().eq('user_id', uid).order('created_at', ascending: false);
      final w = await client.from('withdrawal_requests').select().eq('user_id', uid).order('created_at', ascending: false);
      transactions = t.map((x) => EconomyEntry.transaction(x)).toList(); withdrawals = w.map((x) => EconomyEntry.withdrawal(x)).toList();
    }
    if (mode == 'points') { final p = await client.from('points_ledger').select().eq('user_id', uid).order('created_at', ascending: false); points = p.map((x) => EconomyEntry.points(x)).toList(); }
    return ReporterEconomyData(stats: statsRaw == null ? null : ReporterStats.fromJson(statsRaw), performance: performance, wallet: wallet, points: points, transactions: transactions, withdrawals: withdrawals);
  }
  Future<void> requestWithdrawal({required num amount, required String bankName, required String accountHolder, required String accountNumber, required String bankCode, required String phoneNumber}) async { await client.rpc('request_withdrawal', params: {'amount': amount, 'payout_method': 'Bank transfer', 'payout_details': jsonEncode({'bankName': bankName, 'accountHolder': accountHolder, 'accountNumber': accountNumber, 'bankCode': bankCode, 'phoneNumber': phoneNumber})}); }
  Future<List<ReporterStats>> leaderboard({String? countryId, String? cityId, int? days}) async { final rows = await client.rpc<dynamic>('leaderboard', params: {'scope_country': countryId, 'scope_city': cityId, 'period_days': days}); return (rows as List? ?? const []).whereType<Map>().map((x) => ReporterStats.fromJson(Map<String,dynamic>.from(x))).toList(); }
}
