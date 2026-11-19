import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/ads/ad_widgets.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/presentation/auth_scope.dart';
import '../../legal/domain/legal_destination.dart';
import '../../location/data/location_repository.dart';
import '../../location/domain/location_models.dart';
import '../../news/domain/news_models.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

enum AccountMode { profile, settings, saved, following, comments, appeals }

class AccountScreen extends StatefulWidget {
  const AccountScreen({this.mode = AccountMode.profile, super.key});

  final AccountMode mode;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _fullName = TextEditingController();
  final _bio = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();

  AccountRepository? _repository;
  AccountDeletionRequest? _deletionRequest;
  LocationRow? _homeCity;
  String? _homeCityId;
  List<NewsSummary> _saved = const [];
  AccountFollowingData? _following;
  List<AccountComment> _comments = const [];
  AccountAppealsData? _appeals;
  bool _initialized = false;
  bool _loading = true;
  bool _busy = false;
  bool _showPassword = false;
  bool _showPasswordConfirmation = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final session = AuthScope.read(context);
    final client = session.service.client;
    if (client == null) {
      _loading = false;
      _error = 'Supabase is not configured.';
      return;
    }
    _repository = AccountRepository(client);
    _fullName.text = session.profile?.fullName ?? '';
    _bio.text = session.profile?.bio ?? '';
    _homeCityId = session.profile?.cityId;
    _load();
  }

  @override
  void didUpdateWidget(covariant AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode && _repository != null) _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _bio.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.mode) {
        case AccountMode.profile:
        case AccountMode.settings:
          final session = AuthScope.read(context);
          _fullName.text = session.profile?.fullName ?? '';
          _bio.text = session.profile?.bio ?? '';
          _homeCityId = session.profile?.cityId;
          final results = await Future.wait<dynamic>([
            _repository!.deletionRequest(),
            if (session.profile?.cityId?.isNotEmpty == true)
              _repository!.locations.city(session.profile!.cityId!)
            else
              Future<LocationRow?>.value(),
          ]);
          _deletionRequest = results[0] as AccountDeletionRequest?;
          _homeCity = results[1] as LocationRow?;
          break;
        case AccountMode.saved:
          _saved = await _repository!.savedStories();
          break;
        case AccountMode.following:
          _following = await _repository!.following();
          break;
        case AccountMode.comments:
          _comments = await _repository!.comments();
          break;
        case AccountMode.appeals:
          _appeals = await _repository!.appealsAndReports();
          break;
      }
    } catch (error) {
      if (mounted) _error = AppError.message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_busy) return;
    final session = AuthScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository!.saveProfile(
        fullName: _fullName.text,
        bio: _bio.text,
        cityId: _homeCity?.id ?? _homeCityId,
      );
      await session.syncFromClient();
      if (mounted) _message('Profile saved.');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeAvatar() async {
    if (_busy) return;
    final session = AuthScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final changed = await _repository!.chooseAndUploadAvatar(
        session.profile?.avatarUrl,
      );
      if (!changed) return;
      await session.syncFromClient();
      if (mounted) _message('Profile photo updated.');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseHomeCity() async {
    final city = await showModalBottomSheet<LocationRow>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      builder: (_) => _HomeCityPicker(
        repository: _repository!.locations,
        initialCityId: _homeCity?.id ?? _homeCityId,
      ),
    );
    if (city != null && mounted) {
      setState(() {
        _homeCity = city;
        _homeCityId = city.id;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_busy) return;
    if (_password.text != _passwordConfirmation.text) {
      setState(() => _error = 'The password confirmation does not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository!.changePassword(_password.text);
      _password.clear();
      _passwordConfirmation.clear();
      if (mounted) _message('Password updated.');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeBookmark(NewsSummary story) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repository!.removeBookmark(story.id);
      if (mounted) {
        setState(
          () => _saved = _saved
              .where((item) => item.id != story.id)
              .toList(growable: false),
        );
        _message('Removed from saved stories.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unfollow(AccountFollow follow) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repository!.unfollow(follow);
      if (!mounted) return;
      await _load();
      if (mounted) _message('Unfollowed ${follow.label}.');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _appealVerification() async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appeal verification decision'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 2000,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Explain why the decision should be reviewed',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit appeal'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null || message.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await _repository!.appealVerification(message);
      if (!mounted) return;
      await _load();
      if (mounted) _message('Verification appeal submitted.');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestDeletion() async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The request will be reviewed. Editorial, legal and audit records are not silently deleted.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reason,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep account'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request deletion'),
          ),
        ],
      ),
    );
    final value = reason.text;
    reason.dispose();
    if (confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await _repository!.requestDeletion(value);
      _deletionRequest = AccountDeletionRequest(
        status: 'pending',
        requestedAt: DateTime.now().toUtc(),
      );
      if (mounted) {
        setState(() {});
        _message('Account deletion request submitted.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDeletion() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repository!.cancelDeletion();
      _deletionRequest = AccountDeletionRequest(
        status: 'cancelled',
        requestedAt: _deletionRequest?.requestedAt,
      );
      if (mounted) {
        setState(() {});
        _message('Account deletion request cancelled.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    final session = AuthScope.watch(context);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            mobile ? 14 : 36,
            22,
            mobile ? 14 : 36,
            90,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.contentMax,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AccountPageHeader(
                      mode: widget.mode,
                      title: _title,
                      subtitle: _subtitle,
                      displayName: session.displayName,
                    ),
                    const SizedBox(height: 12),
                    _AccountNavigation(selected: widget.mode),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorNotice(message: _error!, retry: _load),
                    ],
                    const SizedBox(height: 18),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(50),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      _content(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _title => switch (widget.mode) {
    AccountMode.profile => 'Your account',
    AccountMode.settings => 'Account settings',
    AccountMode.saved => 'Saved stories',
    AccountMode.following => 'Following',
    AccountMode.comments => 'Your comments',
    AccountMode.appeals => 'Appeals and reports',
  };

  String get _subtitle => switch (widget.mode) {
    AccountMode.profile =>
      'Manage your public identity and CitizenNews activity.',
    AccountMode.settings =>
      'Control your security, language, advertising and account data.',
    AccountMode.saved => 'Stories you bookmarked for reading later.',
    AccountMode.following =>
      'Reporters, places and topics shaping your personal feed.',
    AccountMode.comments => 'Review your recent community conversations.',
    AccountMode.appeals =>
      'Track verification appeals and submitted content reports.',
  };

  Widget _content() => switch (widget.mode) {
    AccountMode.profile || AccountMode.settings => _profileContent(),
    AccountMode.saved => _savedContent(),
    AccountMode.following => _followingContent(),
    AccountMode.comments => _commentsContent(),
    AccountMode.appeals => _appealsContent(),
  };

  Widget _profileContent() {
    final session = AuthScope.watch(context);
    final profile = session.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                height: 74,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.ink, Color(0xFF304A5D)],
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -38),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.ink,
                      backgroundImage: profile?.avatarUrl != null
                          ? NetworkImage(profile!.avatarUrl!)
                          : null,
                      child: profile?.avatarUrl == null
                          ? Text(
                              session.displayName.isEmpty
                                  ? 'R'
                                  : session.displayName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      session.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (profile?.username.isNotEmpty == true)
                      Text('@${profile!.username}'),
                    if (session.user?.email != null)
                      Text(
                        session.user!.email!,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    if (profile?.bio.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          profile!.bio,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final role in session.roles)
                          Chip(
                            label: Text(role.replaceAll('_', ' ')),
                            visualDensity: VisualDensity.compact,
                          ),
                        Chip(
                          label: Text(
                            session.isSuspended ? 'suspended' : 'active',
                          ),
                          avatar: Icon(
                            session.isSuspended
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _changeAvatar,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(_busy ? 'Please wait...' : 'Change photo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (session.isSuspended) ...[
          const SizedBox(height: 12),
          const _InfoNotice(
            message:
                'This account is suspended. Reporting, chat and administration are unavailable.',
            danger: true,
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 760;
            final editor = _profileEditor();
            final hub = _accountHub(session);
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: editor),
                      const SizedBox(width: 12),
                      Expanded(child: hub),
                    ],
                  )
                : Column(children: [editor, const SizedBox(height: 12), hub]);
          },
        ),
        if (widget.mode == AccountMode.settings) ...[
          const SizedBox(height: 12),
          const LanguageSettingsCard(),
          const SizedBox(height: 12),
          const AdPreferencesCard(),
          const SizedBox(height: 12),
          _securityCard(),
          const SizedBox(height: 12),
          _dataControls(),
        ],
      ],
    );
  }

  Widget _profileEditor() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(
            controller: _fullName,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bio,
            maxLength: 1000,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Bio',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_city_outlined),
            title: Text(
              _homeCity?.name ??
                  (_homeCityId?.isNotEmpty == true
                      ? 'Saved home city'
                      : 'Choose your home city'),
            ),
            subtitle: const Text(
              'Your profile city is separate from the location used to browse news.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _busy ? null : _chooseHomeCity,
          ),
          if (_homeCity != null || _homeCityId?.isNotEmpty == true)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _homeCity = null;
                        _homeCityId = null;
                      }),
                child: const Text('Clear home city'),
              ),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: Text(_busy ? 'Saving...' : 'Save profile'),
          ),
        ],
      ),
    ),
  );

  Widget _accountHub(AuthSessionController session) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const _HubGroupTitle(
            icon: Icons.auto_awesome_mosaic_outlined,
            title: 'Your activity',
          ),
          const _HubLink(
            icon: Icons.bookmark_outline_rounded,
            label: 'Saved stories',
            path: '/saved',
          ),
          const _HubLink(
            icon: Icons.people_outline_rounded,
            label: 'Following',
            path: '/following',
          ),
          const _HubLink(
            icon: Icons.comment_outlined,
            label: 'Your comments',
            path: '/comments',
          ),
          const _HubLink(
            icon: Icons.gavel_outlined,
            label: 'Appeals and reports',
            path: '/appeals',
          ),
          const Divider(),
          const _HubGroupTitle(
            icon: Icons.manage_accounts_outlined,
            title: 'Account tools',
          ),
          const _HubLink(
            icon: Icons.verified_user_outlined,
            label: 'Reporter verification',
            path: '/verification',
          ),
          if (session.isReporter)
            const _HubLink(
              icon: Icons.dashboard_outlined,
              label: 'Reporter dashboard',
              path: '/dashboard',
            ),
          if (session.isAdmin)
            const _HubLink(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin workspace',
              path: '/admin',
            ),
          const _HubLink(
            icon: Icons.settings_outlined,
            label: 'Security and data controls',
            path: '/settings',
          ),
          const Divider(),
          const _HubGroupTitle(
            icon: Icons.info_outline_rounded,
            title: 'CitizenNews and support',
          ),
          for (final destination in legalDestinations)
            _HubLink(
              icon: _accountLegalIcon(destination.path),
              label: context.tr(destination.translationKey),
              path: destination.path,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.red),
            title: const Text('Sign out'),
            onTap: _busy
                ? null
                : () async {
                    await AuthScope.read(context).signOut();
                    if (context.mounted) context.go('/');
                  },
          ),
        ],
      ),
    ),
  );

  Widget _securityCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Change password',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Use at least 8 characters.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: !_showPassword,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordConfirmation,
            obscureText: !_showPasswordConfirmation,
            enableSuggestions: false,
            autocorrect: false,
            onSubmitted: (_) => _changePassword(),
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _showPasswordConfirmation
                    ? 'Hide password'
                    : 'Show password',
                onPressed: () => setState(
                  () => _showPasswordConfirmation =
                      !_showPasswordConfirmation,
                ),
                icon: Icon(
                  _showPasswordConfirmation
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _changePassword,
            child: Text(_busy ? 'Updating...' : 'Update password'),
          ),
        ],
      ),
    ),
  );

  Widget _dataControls() {
    final pending = _deletionRequest?.status == 'pending';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Data controls',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              pending
                  ? 'Your deletion request is pending review${_deletionRequest?.requestedAt == null ? '.' : ' since ${_date(_deletionRequest!.requestedAt)}.'}'
                  : 'Request account deletion without silently removing required editorial, legal or audit records.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (pending)
              OutlinedButton(
                onPressed: _busy ? null : _cancelDeletion,
                child: const Text('Cancel deletion request'),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : _requestDeletion,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Request account deletion'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _savedContent() {
    if (_saved.isEmpty) {
      return const _EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'No saved stories yet',
        message: 'Bookmark a published story and it will appear here.',
      );
    }
    return Column(
      children: [
        for (final story in _saved) ...[
          _AccountStoryCard(
            story: story,
            action: IconButton(
              tooltip: 'Remove bookmark',
              onPressed: _busy ? null : () => _removeBookmark(story),
              icon: const Icon(Icons.bookmark_remove_outlined),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _followingContent() {
    final data = _following;
    if (data == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Following list', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (data.follows.isEmpty)
          const _EmptyState(
            icon: Icons.person_add_alt_rounded,
            title: 'You are not following anything yet',
            message:
                'Follow reporters, cities, areas or categories to build a personal feed.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < data.follows.length; index++) ...[
                  ListTile(
                    leading: Icon(_followIcon(data.follows[index].targetType)),
                    title: Text(data.follows[index].label),
                    subtitle: Text(_capitalize(data.follows[index].targetType)),
                    trailing: TextButton(
                      onPressed: _busy
                          ? null
                          : () => _unfollow(data.follows[index]),
                      child: const Text('Unfollow'),
                    ),
                    onTap: data.follows[index].username?.isNotEmpty == true
                        ? () => context.push(
                            '/reporter/${Uri.encodeComponent(data.follows[index].username!)}',
                          )
                        : null,
                  ),
                  if (index != data.follows.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        const SizedBox(height: 22),
        Text(
          'Stories from following',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (data.stories.isEmpty)
          const _InfoNotice(
            message: 'No published stories from your following list yet.',
          )
        else
          for (final story in data.stories) ...[
            _AccountStoryCard(story: story),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _commentsContent() {
    if (_comments.isEmpty) {
      return const _EmptyState(
        icon: Icons.comment_outlined,
        title: 'No comments yet',
        message: 'Comments you add to published stories will appear here.',
      );
    }
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < _comments.length; index++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              title: Text(_comments[index].body),
              subtitle: Text(
                [
                  if (_comments[index].headline?.isNotEmpty == true)
                    _comments[index].headline!,
                  _date(_comments[index].createdAt),
                ].where((value) => value.isNotEmpty).join(' - '),
              ),
              trailing: _comments[index].slug?.isNotEmpty == true
                  ? const Icon(Icons.open_in_new_rounded)
                  : null,
              onTap: _comments[index].slug?.isNotEmpty == true
                  ? () => context.push('/news/${_comments[index].slug}')
                  : null,
            ),
            if (index != _comments.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _appealsContent() {
    final data = _appeals;
    if (data == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Appeals',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (data.canAppealVerification)
              FilledButton.icon(
                onPressed: _busy ? null : _appealVerification,
                icon: const Icon(Icons.gavel_outlined),
                label: const Text('Appeal verification'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.appeals.isEmpty)
          const _InfoNotice(message: 'You have not submitted any appeals.')
        else
          for (final appeal in data.appeals) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appeal.reason,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _StatusChip(status: appeal.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(appeal.message),
                    if (appeal.adminResponse?.isNotEmpty == true) ...[
                      const Divider(height: 24),
                      const Text(
                        'Admin response',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(appeal.adminResponse!),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _date(appeal.createdAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 22),
        Text(
          'Your content reports',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (data.reports.isEmpty)
          const _InfoNotice(message: 'You have not reported any content.')
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < data.reports.length; index++) ...[
                  ListTile(
                    title: Text(data.reports[index].reason),
                    subtitle: Text(
                      [
                        if (data.reports[index].note?.isNotEmpty == true)
                          data.reports[index].note!,
                        _date(data.reports[index].createdAt),
                      ].where((value) => value.isNotEmpty).join(' - '),
                    ),
                    trailing: _StatusChip(status: data.reports[index].status),
                  ),
                  if (index != data.reports.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AccountPageHeader extends StatelessWidget {
  const _AccountPageHeader({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.displayName,
  });

  final AccountMode mode;
  final String title;
  final String subtitle;
  final String displayName;

  IconData get _icon => switch (mode) {
    AccountMode.profile => Icons.person_outline_rounded,
    AccountMode.settings => Icons.tune_rounded,
    AccountMode.saved => Icons.bookmark_outline_rounded,
    AccountMode.following => Icons.people_outline_rounded,
    AccountMode.comments => Icons.chat_bubble_outline_rounded,
    AccountMode.appeals => Icons.gavel_outlined,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.red.withValues(alpha: .08),
          AppColors.focus.withValues(alpha: .035),
        ],
      ),
      border: Border.all(color: AppColors.red.withValues(alpha: .15)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_icon, color: AppColors.red),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isEmpty
                    ? 'YOUR CITIZENNEWS'
                    : displayName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.25,
                ),
              ),
              const SizedBox(height: 5),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AccountNavigation extends StatelessWidget {
  const _AccountNavigation({required this.selected});
  final AccountMode selected;

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
            (AccountMode.profile, 'Account', Icons.person_outline_rounded, '/account'),
            (AccountMode.saved, 'Saved', Icons.bookmark_outline_rounded, '/saved'),
            (AccountMode.following, 'Following', Icons.people_outline_rounded, '/following'),
            (AccountMode.comments, 'Comments', Icons.chat_bubble_outline_rounded, '/comments'),
            (AccountMode.appeals, 'Appeals', Icons.gavel_outlined, '/appeals'),
            (AccountMode.settings, 'Settings', Icons.tune_rounded, '/settings'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _AccountNavButton(
                label: item.$2,
                icon: item.$3,
                selected: selected == item.$1,
                onTap: () => context.go(item.$4),
              ),
            ),
        ],
      ),
    ),
  );
}

class _AccountNavButton extends StatelessWidget {
  const _AccountNavButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HubLink extends StatelessWidget {
  const _HubLink({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: AppColors.ink),
    ),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.push(path),
  );
}

class _HubGroupTitle extends StatelessWidget {
  const _HubGroupTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.red),
        const SizedBox(width: 7),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.red,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
      ],
    ),
  );
}

class _AccountStoryCard extends StatelessWidget {
  const _AccountStoryCard({required this.story, this.action});
  final NewsSummary story;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/news/${story.slug}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: story.imageUrl?.isNotEmpty == true
                ? Image.network(
                    story.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _StoryImageFallback(),
                  )
                : const _StoryImageFallback(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.category.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    story.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${story.city} - ${story.fullName}',
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
          ),
          if (action != null) action!,
        ],
      ),
    ),
  );
}

class _StoryImageFallback extends StatelessWidget {
  const _StoryImageFallback();
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface,
    alignment: Alignment.center,
    child: const Icon(Icons.newspaper_rounded, color: AppColors.muted),
  );
}

class _HomeCityPicker extends StatefulWidget {
  const _HomeCityPicker({required this.repository, this.initialCityId});
  final LocationRepository repository;
  final String? initialCityId;
  @override
  State<_HomeCityPicker> createState() => _HomeCityPickerState();
}

class _HomeCityPickerState extends State<_HomeCityPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<LocationRow> _countries = const [];
  List<LocationRow> _regions = const [];
  List<LocationRow> _cities = const [];
  String _country = '';
  String _region = '';
  int _page = 0;
  bool _loading = true;
  bool _more = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final current = widget.initialCityId?.isNotEmpty == true
          ? await widget.repository.city(widget.initialCityId!)
          : null;
      _countries = await widget.repository.countries();
      _country = current?.countryId ?? '';
      _region = current?.regionId ?? '';
      if (_country.isNotEmpty) {
        _regions = await widget.repository.regions(_country);
        await _loadCities();
        if (current != null && !_cities.any((city) => city.id == current.id))
          _cities = [current, ..._cities];
      }
    } catch (error) {
      _error = AppError.message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectCountry(String value) async {
    setState(() {
      _country = value;
      _region = '';
      _regions = const [];
      _cities = const [];
      _loading = true;
      _error = null;
    });
    try {
      if (value.isNotEmpty) {
        _regions = await widget.repository.regions(value);
        await _loadCities();
      }
    } catch (error) {
      _error = AppError.message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectRegion(String value) async {
    setState(() {
      _region = value;
      _cities = const [];
    });
    await _loadCities();
  }

  Future<void> _loadCities({bool append = false}) async {
    if (_country.isEmpty) return;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
        _page = append ? _page + 1 : 0;
      });
    try {
      final rows = await widget.repository.cities(
        countryId: _country,
        regionId: _region,
        query: _search.text.trim(),
        page: _page,
      );
      _cities = append ? [..._cities, ...rows] : rows;
      _more = rows.length == 50;
    } catch (error) {
      _error = AppError.message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      14,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose home city',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('home-country-$_country'),
            initialValue: _country,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Country'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Choose country')),
              for (final country in _countries)
                DropdownMenuItem(value: country.id, child: Text(country.name)),
            ],
            onChanged: _loading ? null : (value) => _selectCountry(value ?? ''),
          ),
          if (_regions.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey('home-region-$_region'),
              initialValue: _region,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Region'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All regions')),
                for (final region in _regions)
                  DropdownMenuItem(value: region.id, child: Text(region.name)),
              ],
              onChanged: _loading
                  ? null
                  : (value) => _selectRegion(value ?? ''),
            ),
          ],
          if (_country.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search city',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  _loadCities,
                );
              },
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.red),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading && _cities.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _cities.length + (_more ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == _cities.length)
                        return TextButton(
                          onPressed: _loading
                              ? null
                              : () => _loadCities(append: true),
                          child: const Text('Load more cities'),
                        );
                      final city = _cities[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(city.name),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, city),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.retry});
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

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.message, this.danger = false});
  final String message;
  final bool danger;
  @override
  Widget build(BuildContext context) => Card(
    color: danger ? AppColors.red.withValues(alpha: .07) : AppColors.surface,
    child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.red),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final positive = const {'approved', 'resolved'}.contains(status);
    final negative = const {'rejected', 'dismissed'}.contains(status);
    final color = positive
        ? AppColors.success
        : negative
        ? AppColors.red
        : AppColors.focus;
    return Chip(
      label: Text(_capitalize(status.replaceAll('_', ' '))),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: .35)),
      backgroundColor: color.withValues(alpha: .08),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

IconData _followIcon(String type) => switch (type) {
  'reporter' => Icons.person_outline_rounded,
  'city' => Icons.location_city_outlined,
  'area' => Icons.place_outlined,
  'category' => Icons.category_outlined,
  _ => Icons.bookmark_outline_rounded,
};

IconData _accountLegalIcon(String path) => switch (path) {
  '/about' => Icons.info_outline_rounded,
  '/contact' => Icons.mail_outline_rounded,
  '/privacy' => Icons.privacy_tip_outlined,
  '/copyright' => Icons.copyright_rounded,
  '/corrections-policy' => Icons.fact_check_outlined,
  '/content-removal' => Icons.remove_circle_outline_rounded,
  _ => Icons.policy_outlined,
};

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _date(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
