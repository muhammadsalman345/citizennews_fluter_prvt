import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../../location/data/location_repository.dart';
import '../../location/domain/location_models.dart';
import '../data/reporter_economy_repository.dart';
import '../domain/reporter_economy.dart';

class ReporterLeaderboardScreen extends StatefulWidget {
  const ReporterLeaderboardScreen({super.key});

  @override
  State<ReporterLeaderboardScreen> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<ReporterLeaderboardScreen> {
  ReporterEconomyRepository? _repository;
  LocationRepository? _locations;
  List<ReporterStats> _rows = const [];
  List<LocationRow> _countries = const [];
  List<LocationRow> _cities = const [];
  String _country = '';
  String _city = '';
  int? _days = 30;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repository != null) return;
    final client = AuthScope.read(context).service.client;
    if (client == null) {
      _loading = false;
      _error = 'Supabase is not configured.';
      return;
    }
    _repository = ReporterEconomyRepository(client);
    _locations = LocationRepository(client);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _countries = await _locations!.countries();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AppError.message(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository!.leaderboard(
        countryId: _country.isEmpty ? null : _country,
        cityId: _city.isEmpty ? null : _city,
        days: _days,
      );
      if (mounted) setState(() => _rows = result);
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _countryChanged(String? value) async {
    setState(() {
      _country = value ?? '';
      _city = '';
      _cities = const [];
      _loading = true;
      _error = null;
    });
    try {
      if (_country.isNotEmpty) {
        _cities = await _locations!.cities(countryId: _country);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AppError.message(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 90),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.contentMax,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LeaderboardHeader(),
                      const SizedBox(height: 14),
                      _filters(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _LeaderboardNotice(message: _error!, retry: _load),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Reporter rankings',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Text(
                            '${_rows.length} reporters',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(50),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_rows.isEmpty)
                        const _LeaderboardEmpty()
                      else
                        for (final reporter in _rows) ...[
                          _ReporterRankCard(
                            reporter: reporter,
                            onTap: reporter.username.isEmpty
                                ? null
                                : () => context.push(
                                      '/reporter/${Uri.encodeComponent(reporter.username)}',
                                    ),
                          ),
                          const SizedBox(height: 9),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _filters() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  initialValue: _days ?? 0,
                  decoration: const InputDecoration(
                    labelText: 'Ranking period',
                    prefixIcon: Icon(Icons.date_range_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                    DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                    DropdownMenuItem(value: 0, child: Text('All time')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _days = value == 0 ? null : value);
                          _load();
                        },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _country,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    prefixIcon: Icon(Icons.public_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All countries'),
                    ),
                    for (final country in _countries)
                      DropdownMenuItem(
                        value: country.id,
                        child: Text(country.name),
                      ),
                  ],
                  onChanged: _loading ? null : _countryChanged,
                ),
              ),
              if (_country.isNotEmpty)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _city,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All cities'),
                      ),
                      for (final city in _cities)
                        DropdownMenuItem(
                          value: city.id,
                          child: Text(city.name),
                        ),
                    ],
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() => _city = value ?? '');
                            _load();
                          },
                  ),
                ),
            ],
          ),
        ),
      );
}

class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101826), Color(0xFF26374D)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB020).withValues(alpha: .16),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: Color(0xFFFFC14D),
                size: 29,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CITIZENNEWS COMMUNITY',
                    style: TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Top reporters',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Discover trusted local reporters ranked by verified contribution, trust and community impact.',
                    style: TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ReporterRankCard extends StatelessWidget {
  const _ReporterRankCard({required this.reporter, required this.onTap});

  final ReporterStats reporter;
  final VoidCallback? onTap;

  Color get _rankColor => switch (reporter.rank) {
        1 => const Color(0xFFC88B00),
        2 => const Color(0xFF667581),
        3 => const Color(0xFFA65A2E),
        _ => AppColors.focus,
      };

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _rankColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _rankColor.withValues(alpha: .22),
                    ),
                  ),
                  child: Text(
                    '#${reporter.rank ?? '-'}',
                    style: TextStyle(
                      color: _rankColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              reporter.name.isEmpty
                                  ? '@${reporter.username}'
                                  : reporter.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.focus,
                            size: 17,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${reporter.username} - ${reporter.published} published - ${reporter.followers} followers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${reporter.points} pts',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Rating ${reporter.rating} - Trust ${reporter.trust}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ],
            ),
          ),
        ),
      );
}

class _LeaderboardNotice extends StatelessWidget {
  const _LeaderboardNotice({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.error_outline_rounded),
          title: Text(message),
          trailing: TextButton(onPressed: retry, child: const Text('Retry')),
        ),
      );
}

class _LeaderboardEmpty extends StatelessWidget {
  const _LeaderboardEmpty();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Column(
            children: [
              Icon(Icons.groups_outlined, size: 44, color: AppColors.muted),
              SizedBox(height: 10),
              Text(
                'No ranked reporters for this filter.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
