import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../data/reporter_economy_repository.dart';
import '../domain/reporter_economy.dart';

class ReporterWorkspaceScreen extends StatefulWidget {
  const ReporterWorkspaceScreen({required this.mode, super.key});

  final String mode;

  @override
  State<ReporterWorkspaceScreen> createState() => _ReporterWorkspaceState();
}

class _ReporterWorkspaceState extends State<ReporterWorkspaceScreen> {
  ReporterEconomyRepository? _repository;
  ReporterEconomyData? _data;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int _days = 30;

  final _amount = TextEditingController();
  final _bank = TextEditingController();
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _code = TextEditingController();
  final _phone = TextEditingController();

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
    _load();
  }

  @override
  void didUpdateWidget(covariant ReporterWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode && _repository != null) _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _amount,
      _bank,
      _holder,
      _account,
      _code,
      _phone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository!.load(widget.mode, _days);
      if (mounted) setState(() => _data = result);
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _withdraw() async {
    final wallet = _data?.wallet;
    final value = num.tryParse(_amount.text);
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (value == null ||
        wallet == null ||
        value < wallet.minimum ||
        value > wallet.available) {
      setState(
        () => _error =
            'Enter an amount between ${wallet?.minimum ?? 100} and ${wallet?.available ?? 0}.',
      );
      return;
    }
    if ([_bank, _holder, _account, _phone]
            .any((controller) => controller.text.trim().isEmpty) ||
        digits.length < 7 ||
        digits.length > 15) {
      setState(() => _error = 'Complete valid bank and phone details.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _repository!.requestWithdrawal(
        amount: value,
        bankName: _bank.text.trim(),
        accountHolder: _holder.text.trim(),
        accountNumber: _account.text.trim(),
        bankCode: _code.text.trim(),
        phoneNumber: _phone.text.trim(),
      );
      for (final controller in [
        _amount,
        _bank,
        _holder,
        _account,
        _code,
        _phone,
      ]) {
        controller.clear();
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal request submitted.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _sending = false);
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
                  _WorkspaceHeader(mode: widget.mode),
                  const SizedBox(height: 14),
                  _WorkspaceNavigation(selected: widget.mode),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _WorkspaceNotice(message: _error!, retry: _load),
                  ],
                  const SizedBox(height: 18),
                  if (_loading)
                    const _WorkspaceLoading()
                  else if (_data == null)
                    const _WorkspaceEmpty()
                  else
                    ..._content(_data!),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _content(ReporterEconomyData data) => switch (widget.mode) {
    'points' => _pointsContent(data),
    'wallet' => _walletContent(data),
    _ => _dashboardContent(data),
  };

  List<Widget> _dashboardContent(ReporterEconomyData data) {
    final stats = data.stats;
    final performance = data.performance;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Performance overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          DropdownButton<int>(
            value: _days,
            items: const [
              DropdownMenuItem(value: 7, child: Text('Last 7 days')),
              DropdownMenuItem(value: 30, child: Text('Last 30 days')),
              DropdownMenuItem(value: 36500, child: Text('All time')),
            ],
            onChanged: (value) {
              if (value == null || value == _days) return;
              setState(() => _days = value);
              _load();
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      _MetricGrid(
        metrics: [
          _MetricData('Points', stats?.points ?? 0, Icons.stars_rounded),
          _MetricData(
            'Published',
            stats?.published ?? 0,
            Icons.article_outlined,
          ),
          _MetricData(
            'Followers',
            stats?.followers ?? 0,
            Icons.people_outline_rounded,
          ),
          _MetricData(
            'Trust score',
            stats?.trust ?? 0,
            Icons.verified_user_outlined,
          ),
          _MetricData(
            'Views',
            performance?.views ?? 0,
            Icons.visibility_outlined,
          ),
          _MetricData(
            'Unique views',
            performance?.uniqueViews ?? 0,
            Icons.person_search_outlined,
          ),
          _MetricData(
            'Likes',
            performance?.likes ?? 0,
            Icons.thumb_up_outlined,
          ),
          _MetricData(
            'Comments',
            performance?.comments ?? 0,
            Icons.chat_bubble_outline_rounded,
          ),
        ],
      ),
      const SizedBox(height: 20),
      _EditorialStatusCard(performance: performance),
      if (performance?.daily.isNotEmpty == true) ...[
        const SizedBox(height: 14),
        _DailyViewsCard(entries: performance!.daily),
      ],
    ];
  }

  List<Widget> _pointsContent(ReporterEconomyData data) => [
    _MetricGrid(
      metrics: [
        _MetricData(
          'Total points',
          data.stats?.points ?? 0,
          Icons.stars_rounded,
        ),
        _MetricData(
          'Published stories',
          data.stats?.published ?? 0,
          Icons.article_outlined,
        ),
        _MetricData(
          'Reporter rating',
          data.stats?.rating ?? 0,
          Icons.workspace_premium_outlined,
        ),
        _MetricData(
          'Trust score',
          data.stats?.trust ?? 0,
          Icons.verified_user_outlined,
        ),
      ],
    ),
    const SizedBox(height: 18),
    _LedgerCard(
      title: 'Points activity',
      icon: Icons.history_rounded,
      entries: data.points,
      emptyMessage: 'No points activity yet.',
    ),
  ];

  List<Widget> _walletContent(ReporterEconomyData data) {
    final wallet = data.wallet;
    final currency = wallet?.currency ?? '';
    return [
      _MetricGrid(
        metrics: [
          _MetricData(
            'Available',
            wallet?.available ?? 0,
            Icons.account_balance_wallet_outlined,
            suffix: currency,
          ),
          _MetricData(
            'Pending',
            wallet?.pending ?? 0,
            Icons.schedule_rounded,
            suffix: currency,
          ),
          _MetricData(
            'Reserved',
            wallet?.reserved ?? 0,
            Icons.lock_clock_outlined,
            suffix: currency,
          ),
          _MetricData(
            'Withdrawn',
            wallet?.withdrawn ?? 0,
            Icons.payments_outlined,
            suffix: currency,
          ),
        ],
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final form = _withdrawalCard(wallet);
          final activity = Column(
            children: [
              _LedgerCard(
                title: 'Wallet transactions',
                icon: Icons.receipt_long_outlined,
                entries: data.transactions,
                emptyMessage: 'No wallet transactions yet.',
              ),
              const SizedBox(height: 12),
              _LedgerCard(
                title: 'Withdrawal history',
                icon: Icons.account_balance_outlined,
                entries: data.withdrawals,
                emptyMessage: 'No withdrawals yet.',
              ),
            ],
          );
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: form),
                    const SizedBox(width: 14),
                    Expanded(child: activity),
                  ],
                )
              : Column(children: [form, const SizedBox(height: 12), activity]);
        },
      ),
    ];
  }

  Widget _withdrawalCard(WalletSummary? wallet) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded, color: AppColors.red),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Request bank withdrawal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Minimum ${wallet?.minimum ?? 100} ${wallet?.currency ?? ''}. Requests are reviewed before payout.',
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          _WorkspaceField(
            controller: _amount,
            label: 'Amount',
            icon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
          ),
          _WorkspaceField(
            controller: _bank,
            label: 'Bank name',
            icon: Icons.account_balance_outlined,
          ),
          _WorkspaceField(
            controller: _holder,
            label: 'Account holder',
            icon: Icons.person_outline_rounded,
          ),
          _WorkspaceField(
            controller: _account,
            label: 'Account number / IBAN',
            icon: Icons.credit_card_outlined,
          ),
          _WorkspaceField(
            controller: _code,
            label: 'Bank / branch code (optional)',
            icon: Icons.numbers_rounded,
          ),
          _WorkspaceField(
            controller: _phone,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _sending ? null : _withdraw,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'Submitting...' : 'Request withdrawal'),
          ),
        ],
      ),
    ),
  );
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.mode});

  final String mode;

  String get _title => switch (mode) {
    'points' => 'Points ledger',
    'wallet' => 'Wallet and withdrawals',
    _ => 'Reporter dashboard',
  };

  String get _subtitle => switch (mode) {
    'points' => 'Review the activity contributing to your reporter score.',
    'wallet' => 'Track earnings, transactions and payout requests.',
    _ => 'Monitor newsroom performance and editorial status at a glance.',
  };

  IconData get _icon => switch (mode) {
    'points' => Icons.stars_rounded,
    'wallet' => Icons.account_balance_wallet_outlined,
    _ => Icons.dashboard_outlined,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF172C3A), Color(0xFF304A5D)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CITIZENNEWS NEWSROOM',
                      style: TextStyle(
                        color: Color(0xFFFC8794),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _title,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        color: Color(0xFFD1DCE4),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/my-stories'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              icon: const Icon(Icons.article_outlined),
              label: const Text('My stories'),
            ),
            FilledButton.icon(
              onPressed: () => context.push('/report-news'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New story'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _WorkspaceNavigation extends StatelessWidget {
  const _WorkspaceNavigation({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.paper,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          for (final item in const [
            ('dashboard', 'Dashboard', Icons.dashboard_outlined),
            ('points', 'Points', Icons.stars_outlined),
            ('wallet', 'Wallet', Icons.account_balance_wallet_outlined),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _WorkspaceNavButton(
                label: item.$2,
                icon: item.$3,
                selected: selected == item.$1,
                onTap: () => context.go('/${item.$1}'),
              ),
            ),
          TextButton.icon(
            onPressed: () => context.push('/reporters'),
            icon: const Icon(Icons.leaderboard_outlined),
            label: const Text('Leaderboard'),
          ),
        ],
      ),
    ),
  );
}

class _WorkspaceNavButton extends StatelessWidget {
  const _WorkspaceNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.red : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, {this.suffix = ''});

  final String label;
  final num value;
  final IconData icon;
  final String suffix;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 4
          : constraints.maxWidth >= 620
          ? 2
          : 1;
      const gap = 10.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final metric in metrics)
            SizedBox(width: width, child: _MetricCard(metric: metric)),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: AppColors.red, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${metric.value}${metric.suffix.isEmpty ? '' : ' ${metric.suffix}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EditorialStatusCard extends StatelessWidget {
  const _EditorialStatusCard({required this.performance});

  final Performance? performance;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Editorial pipeline',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Track stories currently moving through editorial review.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _PipelineChip(
                label: 'Pending',
                value: performance?.pending ?? 0,
                color: AppColors.focus,
              ),
              _PipelineChip(
                label: 'Changes requested',
                value: performance?.changes ?? 0,
                color: const Color(0xFFB36A00),
              ),
              _PipelineChip(
                label: 'Rejected',
                value: performance?.rejected ?? 0,
                color: AppColors.red,
              ),
              _PipelineChip(
                label: 'Dislikes',
                value: performance?.dislikes ?? 0,
                color: AppColors.muted,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PipelineChip extends StatelessWidget {
  const _PipelineChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      border: Border.all(color: color.withValues(alpha: .22)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$label  $value',
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    ),
  );
}

class _DailyViewsCard extends StatelessWidget {
  const _DailyViewsCard({required this.entries});

  final List<DailyViews> entries;

  @override
  Widget build(BuildContext context) {
    final maximum = entries.fold<double>(
      1,
      (value, entry) => entry.views.toDouble() > value
          ? entry.views.toDouble()
          : value,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Daily views', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            for (final entry in entries) ...[
              Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      entry.day,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: entry.views.toDouble() / maximum,
                        minHeight: 8,
                        backgroundColor: AppColors.surface,
                        color: AppColors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${entry.views}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.title,
    required this.icon,
    required this.entries,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final List<EconomyEntry> entries;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 4, 5, 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            )
          else
            for (var index = 0; index < entries.length; index++) ...[
              _LedgerTile(entry: entries[index]),
              if (index != entries.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    ),
  );
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final EconomyEntry entry;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 5),
    leading: const CircleAvatar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.red,
      child: Icon(Icons.receipt_outlined, size: 19),
    ),
    title: Text(entry.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      [entry.status, _compactDate(entry.createdAt)]
          .where((value) => value.isNotEmpty)
          .join(' • '),
    ),
    trailing: Text(
      '${entry.amount}${entry.currency.isEmpty ? '' : ' ${entry.currency}'}',
      style: const TextStyle(fontWeight: FontWeight.w900),
    ),
  );
}

class _WorkspaceField extends StatelessWidget {
  const _WorkspaceField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    ),
  );
}

class _WorkspaceNotice extends StatelessWidget {
  const _WorkspaceNotice({required this.message, required this.retry});

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

class _WorkspaceLoading extends StatelessWidget {
  const _WorkspaceLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(50),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _WorkspaceEmpty extends StatelessWidget {
  const _WorkspaceEmpty();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(36),
      child: Column(
        children: [
          Icon(Icons.dashboard_outlined, size: 44, color: AppColors.red),
          SizedBox(height: 10),
          Text('No reporter data is available yet.'),
        ],
      ),
    ),
  );
}

String _compactDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
