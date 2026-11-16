import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../../location/domain/location_models.dart';
import '../data/admin_operations_repository.dart';

class AdminRemainingTab extends StatefulWidget {
  const AdminRemainingTab({
    required this.tab,
    required this.refreshToken,
    required this.isSuperAdmin,
    required this.onOpenTab,
    super.key,
  });

  final String tab;
  final int refreshToken;
  final bool isSuperAdmin;
  final ValueChanged<String> onOpenTab;

  @override
  State<AdminRemainingTab> createState() => _AdminRemainingTabState();
}

class _AdminRemainingTabState extends State<AdminRemainingTab> {
  AdminOperationsRepository? _repository;
  AdminOverviewData? _overview;
  List<AdminContentReport> _reports = const [];
  List<AdminChatReport> _chatReports = const [];
  List<AdminAppeal> _appeals = const [];
  List<AdminUserRecord> _users = const [];
  List<AdminDeletionRequest> _deletions = const [];
  List<AdminWithdrawal> _withdrawals = const [];
  List<AdminCategoryRecord> _categories = const [];
  List<AdminSettingRecord> _settings = const [];
  List<AdminContactMessage> _contacts = const [];
  List<AdminAuditEntry> _audit = const [];
  List<LocationRow> _countries = const [];
  List<LocationRow> _regions = const [];
  List<LocationRow> _cities = const [];
  String _countryId = '';
  String _regionId = '';
  String _query = '';
  String? _error;
  bool _initialized = false;
  bool _loading = true;
  bool _busy = false;
  bool _hasMore = false;
  int _limit = 50;
  int _loadRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final client = AuthScope.read(context).service.client;
    if (client == null) {
      _loading = false;
      _error = 'Supabase is not configured.';
      return;
    }
    _repository = AdminOperationsRepository(client);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AdminRemainingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab ||
        oldWidget.refreshToken != widget.refreshToken) {
      _limit = 50;
      _query = '';
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) return;
    final revision = ++_loadRevision;
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = false;
    });
    try {
      switch (widget.tab) {
        case 'overview':
          _overview = await repository.overview();
          break;
        case 'reports':
          final rows = await repository.contentReports(limit: _limit + 1);
          _hasMore = rows.length > _limit;
          _reports = rows.take(_limit).toList(growable: false);
          break;
        case 'chat-reports':
          final rows = await repository.chatReports(limit: _limit + 1);
          _hasMore = rows.length > _limit;
          _chatReports = rows.take(_limit).toList(growable: false);
          break;
        case 'appeals':
          final rows = await repository.appeals(limit: _limit + 1);
          _hasMore = rows.length > _limit;
          _appeals = rows.take(_limit).toList(growable: false);
          break;
        case 'users':
          final rows = await repository.users(limit: _limit + 1);
          _hasMore = rows.length > _limit;
          _users = rows.take(_limit).toList(growable: false);
          break;
        case 'deletions':
          final rows = await repository.deletionRequests(limit: _limit + 1);
          _hasMore = rows.length > _limit;
          _deletions = rows.take(_limit).toList(growable: false);
          break;
        case 'withdrawals':
          final results = await Future.wait<dynamic>([
            repository.withdrawals(limit: _limit + 1),
            repository.users(limit: 500),
          ]);
          final rows = results[0] as List<AdminWithdrawal>;
          _hasMore = rows.length > _limit;
          _withdrawals = rows.take(_limit).toList(growable: false);
          _users = results[1] as List<AdminUserRecord>;
          break;
        case 'categories':
          _categories = await repository.categories();
          break;
        case 'locations':
          await _loadLocations();
          break;
        case 'settings':
          _settings = widget.isSuperAdmin
              ? await repository.settings()
              : const [];
          break;
        case 'contact':
          final rows = await repository.contacts(limit: _limit + 1);
          _hasMore = rows.length > _limit;
          _contacts = rows.take(_limit).toList(growable: false);
          break;
        case 'audit':
          final rows = await repository.audit(limit: _limit + 1);
          _hasMore = rows.length > _limit;
          _audit = rows.take(_limit).toList(growable: false);
          break;
      }
    } catch (error) {
      if (mounted && revision == _loadRevision) {
        _error = AppError.message(error);
      }
    } finally {
      if (mounted && revision == _loadRevision) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadLocations() async {
    final repository = _repository!;
    _countries = await repository.countries();
    if (_countries.isEmpty) {
      _regions = const [];
      _cities = const [];
      return;
    }
    if (!_countries.any((country) => country.id == _countryId)) {
      _countryId = _countries.first.id;
      _regionId = '';
    }
    final results = await Future.wait<dynamic>([
      repository.regions(_countryId),
      repository.cities(_countryId, _regionId),
    ]);
    _regions = results[0] as List<LocationRow>;
    _cities = results[1] as List<LocationRow>;
  }

  Future<void> _selectCountry(String value) async {
    setState(() {
      _countryId = value;
      _regionId = '';
      _loading = true;
    });
    try {
      await _loadLocations();
    } catch (error) {
      _error = AppError.message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectRegion(String value) async {
    setState(() {
      _regionId = value;
      _loading = true;
    });
    try {
      _cities = await _repository!.cities(_countryId, _regionId);
    } catch (error) {
      _error = AppError.message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    String success = 'Admin action completed.',
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask({
    required String title,
    required String label,
    String initial = '',
    int maxLength = 1000,
    bool multiline = true,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 6 : 1,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => FilledButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, value.text.trim()),
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _resolveReport(
    AdminContentReport report,
    String decision,
  ) async {
    final response = await _ask(
      title: '${_pretty(decision)} report',
      label: 'Admin response',
    );
    if (response == null) return;
    await _run(() => _repository!.resolveReport(report.id, decision, response));
  }

  Future<void> _hideComment(AdminContentReport report) async {
    final response = await _ask(
      title: 'Hide reported comment',
      label: 'Moderation reason',
    );
    if (response == null) return;
    await _run(
      () => _repository!.hideCommentAndResolve(report, response),
      success: 'Comment hidden and report resolved.',
    );
  }

  Future<void> _resolveChat(
    AdminChatReport report,
    String decision, {
    bool suspend = false,
  }) async {
    if (suspend &&
        !await _confirm(
          'Suspend message sender?',
          'This resolves the report and suspends the sender account.',
        )) {
      return;
    }
    final response = await _ask(
      title: '${_pretty(decision)} chat report',
      label: 'Admin response',
    );
    if (response == null) return;
    await _run(
      () => _repository!.resolveChatReport(
        reportId: report.id,
        decision: decision,
        response: response,
        suspendSender: suspend,
      ),
    );
  }

  Future<void> _resolveAppeal(AdminAppeal appeal, String decision) async {
    final response = await _ask(
      title: '${_pretty(decision)} appeal',
      label: 'Response to member',
    );
    if (response == null) return;
    await _run(() => _repository!.resolveAppeal(appeal.id, decision, response));
  }

  Future<void> _accountAction(AdminUserRecord user, String action) async {
    final reason = await _ask(
      title: '${_pretty(action)} ${user.fullName}',
      label: 'Required audit reason',
    );
    if (reason == null) return;
    await _run(() => _repository!.accountAction(user.id, action, reason));
  }

  Future<void> _adjustMetric(AdminUserRecord user, bool trust) async {
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (context) => _NumberReasonDialog(
        title: trust ? 'Adjust trust score' : 'Adjust points',
        numberLabel: trust ? 'New score' : 'Points adjustment',
      ),
    );
    if (result == null) return;
    await _run(() {
      if (trust) {
        return _repository!.adjustTrust(user.id, result.$1, result.$2);
      }
      return _repository!.adjustPoints(user.id, result.$1.round(), result.$2);
    });
  }

  Future<void> _reviewWithdrawal(
    AdminWithdrawal withdrawal,
    String decision,
  ) async {
    final note = await _ask(
      title: '${_pretty(decision)} withdrawal',
      label: 'Admin note',
    );
    if (note == null) return;
    await _run(
      () => _repository!.reviewWithdrawal(
        withdrawalId: withdrawal.id,
        decision: decision,
        note: note,
      ),
    );
  }

  Future<void> _recordPaid(AdminWithdrawal withdrawal) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _PaymentDialog(),
    );
    if (result == null) return;
    await _run(
      () => _repository!.reviewWithdrawal(
        withdrawalId: withdrawal.id,
        decision: 'paid',
        note: result.$2,
        paymentReference: result.$1,
      ),
      success: 'Payment recorded.',
    );
  }

  Future<void> _walletAdjustment() async {
    final result = await showDialog<(String, double, String)>(
      context: context,
      builder: (_) => _WalletAdjustmentDialog(users: _users),
    );
    if (result == null) return;
    await _run(
      () => _repository!.adjustWallet(result.$1, result.$2, result.$3),
      success: 'Wallet adjustment recorded.',
    );
  }

  Future<void> _addCategory() async {
    final name = await _ask(
      title: 'Add category',
      label: 'Category name',
      maxLength: 100,
      multiline: false,
    );
    if (name == null) return;
    await _run(
      () => _repository!.addCategory(name),
      success: 'Category added.',
    );
  }

  Future<void> _addCity() async {
    final result = await showDialog<_CityInput>(
      context: context,
      builder: (_) => _AddCityDialog(repository: _repository!),
    );
    if (result == null) return;
    await _run(
      () => _repository!.addCity(
        name: result.name,
        countryId: result.countryId,
        regionId: result.regionId,
        timezone: result.timezone,
        latitude: result.latitude,
        longitude: result.longitude,
      ),
      success: 'City added.',
    );
  }

  Future<void> _editSetting(AdminSettingRecord setting) async {
    final controller = TextEditingController(text: setting.prettyValue);
    String? validation;
    final value = await showDialog<dynamic>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${setting.key}'),
          content: SizedBox(
            width: 600,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 10,
              maxLines: 18,
              decoration: InputDecoration(
                labelText: 'Valid JSON value',
                errorText: validation,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  Navigator.pop(dialogContext, jsonDecode(controller.text));
                } catch (_) {
                  setDialogState(() => validation = 'Enter valid JSON.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _run(
      () => _repository!.saveSetting(setting.key, value),
      success: 'Setting updated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          _OpsNotice(message: _error!, danger: true),
          const SizedBox(height: 10),
        ],
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() => switch (widget.tab) {
    'overview' => _overviewBody(),
    'reports' => _reportsBody(),
    'chat-reports' => _chatReportsBody(),
    'appeals' => _appealsBody(),
    'users' => _usersBody(),
    'deletions' => _deletionsBody(),
    'withdrawals' => _withdrawalsBody(),
    'categories' => _categoriesBody(),
    'locations' => _locationsBody(),
    'settings' => _settingsBody(),
    'contact' => _contactsBody(),
    'audit' => _auditBody(),
    _ => const Center(child: Text('Unknown admin tab.')),
  };

  Widget _overviewBody() {
    final data = _overview;
    if (data == null) return const _OpsEmpty('Overview is unavailable.');
    final stats = [
      (
        'verification',
        'Pending verifications',
        data.pendingVerifications,
        Icons.verified_user_outlined,
      ),
      ('news', 'Pending stories', data.pendingNews, Icons.fact_check_outlined),
      (
        'revisions',
        'Pending corrections',
        data.pendingRevisions,
        Icons.change_circle_outlined,
      ),
      ('reports', 'Content reports', data.pendingReports, Icons.flag_outlined),
      (
        'chat-reports',
        'Chat reports',
        data.pendingChatReports,
        Icons.report_gmailerrorred_outlined,
      ),
      ('appeals', 'Appeals', data.pendingAppeals, Icons.gavel_outlined),
      (
        'withdrawals',
        'Payout reviews',
        data.pendingWithdrawals,
        Icons.payments_outlined,
      ),
    ];
    return ListView(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats
              .map(
                (item) => _OpsStat(
                  label: item.$2,
                  value: item.$3,
                  icon: item.$4,
                  onTap: () => widget.onOpenTab(item.$1),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        Text(
          'Recent audit activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (data.recentAudit.isEmpty)
          const _OpsEmpty('No audit activity yet.')
        else
          ...data.recentAudit.map(_auditCard),
      ],
    );
  }

  Widget _reportsBody() => _pagedList(
    rows: _reports,
    empty: 'No content reports.',
    item: (report) => _OpsPanel(
      title: report.reason,
      subtitle: '${_pretty(report.status)} · ${_when(report.createdAt)}',
      children: [
        Text(report.note.isEmpty ? 'No report note.' : report.note),
        if (report.storyHeadline != null) ...[
          const SizedBox(height: 10),
          _OpsNotice(
            message:
                '${report.storyHeadline}\nContent status: ${_pretty(report.storyStatus ?? '')}',
          ),
          if (report.storySlug != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/news/${report.storySlug}'),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open reported story'),
              ),
            ),
        ],
        if (report.commentBody != null)
          _OpsNotice(message: 'Reported comment:\n${report.commentBody}'),
        if (report.adminResponse != null)
          Text('Admin response: ${report.adminResponse}'),
        _actions([
          _action('Investigate', () => _resolveReport(report, 'investigating')),
          _action('Dismiss', () => _resolveReport(report, 'dismissed')),
          _action(
            'Resolve',
            () => _resolveReport(report, 'resolved'),
            primary: true,
          ),
          if (report.commentId != null && !report.commentHidden)
            _action(
              'Hide comment + resolve',
              () => _hideComment(report),
              danger: true,
            ),
        ]),
      ],
    ),
  );

  Widget _chatReportsBody() => _pagedList(
    rows: _chatReports,
    empty: 'No chat reports.',
    item: (report) => _OpsPanel(
      title: 'Reported message',
      subtitle: '${_pretty(report.status)} · ${_when(report.createdAt)}',
      children: [
        _OpsNotice(message: report.messageBody),
        Text('Reason: ${report.reason}'),
        if (report.adminResponse != null)
          Text('Admin response: ${report.adminResponse}'),
        _actions([
          _action('Investigate', () => _resolveChat(report, 'investigating')),
          _action('Dismiss', () => _resolveChat(report, 'dismissed')),
          _action(
            'Resolve',
            () => _resolveChat(report, 'resolved'),
            primary: true,
          ),
          _action(
            'Resolve + suspend sender',
            () => _resolveChat(report, 'resolved', suspend: true),
            danger: true,
          ),
        ]),
      ],
    ),
  );

  Widget _appealsBody() => _pagedList(
    rows: _appeals,
    empty: 'No appeals.',
    item: (appeal) => _OpsPanel(
      title: appeal.reason,
      subtitle:
          '${appeal.userName} · ${_pretty(appeal.status)} · ${_when(appeal.createdAt)}',
      children: [
        Text(appeal.message),
        Text(
          appeal.postId != null
              ? 'News appeal'
              : 'Identity verification appeal',
          style: const TextStyle(color: AppColors.muted),
        ),
        if (appeal.adminResponse != null)
          Text('Admin response: ${appeal.adminResponse}'),
        if (appeal.status == 'pending')
          _actions([
            _action(
              'Approve',
              () => _resolveAppeal(appeal, 'approved'),
              primary: true,
            ),
            _action(
              'Reject',
              () => _resolveAppeal(appeal, 'rejected'),
              danger: true,
            ),
          ]),
      ],
    ),
  );

  Widget _usersBody() {
    final query = _query.trim().toLowerCase();
    final rows = query.isEmpty
        ? _users
        : _users
              .where(
                (user) =>
                    user.fullName.toLowerCase().contains(query) ||
                    user.username.toLowerCase().contains(query),
              )
              .toList();
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search loaded users',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _pagedList(
            rows: rows,
            empty: 'No users found.',
            item: (user) => _OpsPanel(
              title: '${user.fullName} / @${user.username}',
              subtitle:
                  '${_pretty(user.status)} · ${user.roles.isEmpty ? 'user' : user.roles.map(_pretty).join(', ')}',
              children: [
                _actions([
                  if (user.status == 'active')
                    _action(
                      'Suspend',
                      () => _accountAction(user, 'suspend'),
                      danger: true,
                    )
                  else
                    _action(
                      'Reactivate',
                      () => _accountAction(user, 'reactivate'),
                      primary: true,
                    ),
                  if (widget.isSuperAdmin) ...[
                    if (user.roles.contains('trusted_reporter'))
                      _action(
                        'Remove trusted',
                        () => _accountAction(user, 'remove_trusted_reporter'),
                      )
                    else
                      _action(
                        'Make trusted',
                        () => _accountAction(user, 'trusted_reporter'),
                      ),
                    if (user.roles.contains('admin'))
                      _action(
                        'Remove admin',
                        () => _accountAction(user, 'remove_admin'),
                        danger: true,
                      )
                    else
                      _action(
                        'Make admin',
                        () => _accountAction(user, 'admin'),
                      ),
                    _action('Adjust trust', () => _adjustMetric(user, true)),
                    _action('Adjust points', () => _adjustMetric(user, false)),
                  ],
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _deletionsBody() => ListView(
    children: [
      const _OpsNotice(
        message:
            'Deletion requests are retained for legal/editorial review. This queue is read-only; no client-side hard delete is provided.',
      ),
      const SizedBox(height: 10),
      if (_deletions.isEmpty)
        const _OpsEmpty('No account deletion requests.')
      else
        ..._deletions.map(
          (request) => _OpsPanel(
            title: request.userName,
            subtitle:
                '${_pretty(request.status)} · ${_when(request.requestedAt)}',
            children: [
              Text(request.reason ?? 'No deletion reason provided.'),
              if (request.adminNote != null)
                Text('Admin note: ${request.adminNote}'),
            ],
          ),
        ),
      if (_hasMore) _loadMoreButton(),
    ],
  );

  Widget _withdrawalsBody() => ListView(
    children: [
      if (widget.isSuperAdmin)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _walletAdjustment,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Wallet adjustment'),
          ),
        ),
      const SizedBox(height: 10),
      if (_withdrawals.isEmpty)
        const _OpsEmpty('No withdrawal requests.')
      else
        ..._withdrawals.map((withdrawal) {
          final details = withdrawal.structuredPayoutDetails;
          return _OpsPanel(
            title:
                '${withdrawal.userName} · ${withdrawal.currency} ${withdrawal.amount.toStringAsFixed(2)}',
            subtitle:
                '${_pretty(withdrawal.payoutMethod)} · ${_pretty(withdrawal.status)} · ${_when(withdrawal.createdAt)}',
            children: [
              if (withdrawal.adminNotes != null)
                Text('Admin note: ${withdrawal.adminNotes}'),
              if (withdrawal.paymentReference != null)
                Text('Payment reference: ${withdrawal.paymentReference}'),
              if (withdrawal.paidAt != null)
                Text('Paid: ${_when(withdrawal.paidAt!)}'),
              if (details != null)
                ...details.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text('${_pretty(entry.key)}: ${entry.value}'),
                  ),
                )
              else
                SelectableText(withdrawal.payoutDetails),
              _actions([
                if (withdrawal.status == 'pending')
                  _action(
                    'Approve',
                    () => _reviewWithdrawal(withdrawal, 'approved'),
                    primary: true,
                  ),
                if (withdrawal.status == 'approved')
                  _action(
                    'Record paid',
                    () => _recordPaid(withdrawal),
                    primary: true,
                  ),
                if (const {'pending', 'approved'}.contains(withdrawal.status))
                  _action(
                    'Reject',
                    () => _reviewWithdrawal(withdrawal, 'rejected'),
                    danger: true,
                  ),
              ]),
            ],
          );
        }),
      if (_hasMore) _loadMoreButton(),
    ],
  );

  Widget _categoriesBody() => ListView(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _busy ? null : _addCategory,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add category'),
        ),
      ),
      const SizedBox(height: 10),
      if (_categories.isEmpty)
        const _OpsEmpty('No categories configured.')
      else
        ..._categories.map(
          (category) => Card(
            child: ListTile(
              title: Text(category.name),
              subtitle: Text(category.slug),
              trailing: _StatusChip(category.active ? 'active' : 'inactive'),
            ),
          ),
        ),
    ],
  );

  Widget _locationsBody() => Column(
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: _countryId.isEmpty ? null : _countryId,
              decoration: const InputDecoration(labelText: 'Country'),
              items: _countries
                  .map(
                    (row) =>
                        DropdownMenuItem(value: row.id, child: Text(row.name)),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) unawaited(_selectCountry(value));
                    },
            ),
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: _regionId,
              decoration: const InputDecoration(labelText: 'Region'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All regions')),
                ..._regions.map(
                  (row) =>
                      DropdownMenuItem(value: row.id, child: Text(row.name)),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) unawaited(_selectRegion(value));
                    },
            ),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _addCity,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add city'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Expanded(
        child: _cities.isEmpty
            ? const _OpsEmpty('No cities found for this selection.')
            : ListView.builder(
                itemCount: _cities.length,
                itemBuilder: (_, index) {
                  final city = _cities[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(city.name),
                      subtitle: Text(
                        [city.timezone, city.slug]
                            .where((value) => value?.isNotEmpty == true)
                            .join(' · '),
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );

  Widget _settingsBody() {
    if (!widget.isSuperAdmin) {
      return const _OpsEmpty('Settings can only be changed by a super admin.');
    }
    return ListView(
      children: _settings
          .map(
            (setting) => _OpsPanel(
              title: setting.key,
              subtitle: 'JSON configuration',
              children: [
                SelectableText(setting.prettyValue),
                _actions([
                  _action(
                    'Edit JSON',
                    () => _editSetting(setting),
                    primary: true,
                  ),
                ]),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _contactsBody() => _pagedList(
    rows: _contacts,
    empty: 'No contact messages.',
    item: (message) => _OpsPanel(
      title: message.subject,
      subtitle:
          '${message.name} · ${message.email} · ${_when(message.createdAt)}',
      children: [SelectableText(message.message)],
    ),
  );

  Widget _auditBody() =>
      _pagedList(rows: _audit, empty: 'No audit entries.', item: _auditCard);

  Widget _auditCard(AdminAuditEntry entry) => _OpsPanel(
    title: '${_pretty(entry.entity)} · ${_pretty(entry.action)}',
    subtitle: _when(entry.createdAt),
    children: [
      Text(entry.reason.isEmpty ? 'No reason recorded.' : entry.reason),
    ],
  );

  Widget _pagedList<T>({
    required List<T> rows,
    required String empty,
    required Widget Function(T row) item,
  }) => ListView(
    children: [
      if (rows.isEmpty) _OpsEmpty(empty) else ...rows.map(item),
      if (_hasMore) _loadMoreButton(),
    ],
  );

  Widget _loadMoreButton() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: OutlinedButton(
      onPressed: _busy
          ? null
          : () {
              _limit += 50;
              unawaited(_load());
            },
      child: const Text('Load more'),
    ),
  );

  Widget _actions(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(spacing: 8, runSpacing: 8, children: children),
  );

  Widget _action(
    String label,
    VoidCallback onPressed, {
    bool primary = false,
    bool danger = false,
  }) {
    if (primary) {
      return FilledButton(
        onPressed: _busy ? null : onPressed,
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: _busy ? null : onPressed,
      style: danger
          ? OutlinedButton.styleFrom(foregroundColor: AppColors.red)
          : null,
      child: Text(label),
    );
  }
}

class _OpsPanel extends StatelessWidget {
  const _OpsPanel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: AppColors.muted)),
          if (children.isNotEmpty) const SizedBox(height: 12),
          ...children.expand((child) => [child, const SizedBox(height: 7)]),
        ],
      ),
    ),
  );
}

class _OpsNotice extends StatelessWidget {
  const _OpsNotice({required this.message, this.danger = false});

  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: danger ? AppColors.red.withValues(alpha: .07) : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: danger ? AppColors.red.withValues(alpha: .18) : AppColors.border,
      ),
    ),
    child: Text(message),
  );
}

class _OpsEmpty extends StatelessWidget {
  const _OpsEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
    ),
  );
}

class _OpsStat extends StatelessWidget {
  const _OpsStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.red),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(label, style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) =>
      Chip(visualDensity: VisualDensity.compact, label: Text(_pretty(status)));
}

class _NumberReasonDialog extends StatefulWidget {
  const _NumberReasonDialog({required this.title, required this.numberLabel});

  final String title;
  final String numberLabel;

  @override
  State<_NumberReasonDialog> createState() => _NumberReasonDialogState();
}

class _NumberReasonDialogState extends State<_NumberReasonDialog> {
  final number = TextEditingController();
  final reason = TextEditingController();

  @override
  void dispose() {
    number.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: number,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(labelText: widget.numberLabel),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: reason,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Required audit reason'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            double.tryParse(number.text.trim()) != null &&
                reason.text.trim().isNotEmpty
            ? () => Navigator.pop(context, (
                double.parse(number.text.trim()),
                reason.text.trim(),
              ))
            : null,
        child: const Text('Confirm'),
      ),
    ],
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog();

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final reference = TextEditingController();
  final note = TextEditingController();

  @override
  void dispose() {
    reference.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record withdrawal as paid'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: reference,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Payment reference'),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          controller: note,
          maxLength: 1000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Payment note'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            reference.text.trim().length >= 4 && note.text.trim().isNotEmpty
            ? () => Navigator.pop(context, (
                reference.text.trim(),
                note.text.trim(),
              ))
            : null,
        child: const Text('Record paid'),
      ),
    ],
  );
}

class _WalletAdjustmentDialog extends StatefulWidget {
  const _WalletAdjustmentDialog({required this.users});

  final List<AdminUserRecord> users;

  @override
  State<_WalletAdjustmentDialog> createState() =>
      _WalletAdjustmentDialogState();
}

class _WalletAdjustmentDialogState extends State<_WalletAdjustmentDialog> {
  final amount = TextEditingController();
  final reason = TextEditingController();
  String userId = '';

  @override
  void initState() {
    super.initState();
    if (widget.users.isNotEmpty) userId = widget.users.first.id;
  }

  @override
  void dispose() {
    amount.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(amount.text.trim());
    return AlertDialog(
      title: const Text('Audited wallet adjustment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: userId.isEmpty ? null : userId,
            decoration: const InputDecoration(labelText: 'User'),
            items: widget.users
                .map(
                  (user) => DropdownMenuItem(
                    value: user.id,
                    child: Text(user.fullName),
                  ),
                )
                .toList(),
            onChanged: (next) => setState(() => userId = next ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(labelText: 'Amount (+ or -)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reason,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Required audit reason',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              userId.isNotEmpty &&
                  value != null &&
                  value != 0 &&
                  reason.text.trim().isNotEmpty
              ? () =>
                    Navigator.pop(context, (userId, value!, reason.text.trim()))
              : null,
          child: const Text('Apply adjustment'),
        ),
      ],
    );
  }
}

class _CityInput {
  const _CityInput({
    required this.name,
    required this.countryId,
    required this.regionId,
    required this.timezone,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String countryId;
  final String regionId;
  final String timezone;
  final double latitude;
  final double longitude;
}

class _AddCityDialog extends StatefulWidget {
  const _AddCityDialog({required this.repository});

  final AdminOperationsRepository repository;

  @override
  State<_AddCityDialog> createState() => _AddCityDialogState();
}

class _AddCityDialogState extends State<_AddCityDialog> {
  final name = TextEditingController();
  final timezone = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  List<LocationRow> countries = const [];
  List<LocationRow> regions = const [];
  String countryId = '';
  String regionId = '';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      countries = await widget.repository.countries();
      if (countries.isNotEmpty) {
        countryId = countries.first.id;
        regions = await widget.repository.regions(countryId);
      }
    } catch (exception) {
      error = AppError.message(exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _countryChanged(String value) async {
    setState(() {
      countryId = value;
      regionId = '';
      loading = true;
    });
    try {
      regions = await widget.repository.regions(value);
    } catch (exception) {
      error = AppError.message(exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    timezone.dispose();
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(latitude.text.trim());
    final lng = double.tryParse(longitude.text.trim());
    final valid =
        name.text.trim().isNotEmpty &&
        countryId.isNotEmpty &&
        lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
    return AlertDialog(
      title: const Text('Add city'),
      content: SizedBox(
        width: 560,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      _OpsNotice(message: error!, danger: true),
                    TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'City name'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: countryId.isEmpty ? null : countryId,
                      decoration: const InputDecoration(labelText: 'Country'),
                      items: countries
                          .map(
                            (country) => DropdownMenuItem(
                              value: country.id,
                              child: Text(country.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) unawaited(_countryChanged(value));
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: regionId,
                      decoration: const InputDecoration(labelText: 'Region'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No region'),
                        ),
                        ...regions.map(
                          (region) => DropdownMenuItem(
                            value: region.id,
                            child: Text(region.name),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => regionId = value ?? ''),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: timezone,
                      decoration: const InputDecoration(
                        labelText: 'Timezone (for example Asia/Karachi)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: longitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  _CityInput(
                    name: name.text.trim(),
                    countryId: countryId,
                    regionId: regionId,
                    timezone: timezone.text.trim(),
                    latitude: lat!,
                    longitude: lng!,
                  ),
                )
              : null,
          child: const Text('Add city'),
        ),
      ],
    );
  }
}

String _pretty(String value) => value
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _when(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
