import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/ads/ads_scope.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/language_picker.dart';
import '../../core/network/network_controller.dart';
import '../../core/network/network_scope.dart';
import '../../core/network/network_status_banner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/presentation/auth_scope.dart';
import '../../features/legal/domain/legal_destination.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NetworkController? _network;
  bool _wasOffline = false;

  bool _selected(String path) => path == '/'
      ? widget.location == '/'
      : widget.location == path || widget.location.startsWith('$path/');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final network = NetworkScope.read(context);
    if (identical(network, _network)) return;
    _network?.removeListener(_handleNetworkChange);
    _network = network;
    _wasOffline = network.offline;
    network.addListener(_handleNetworkChange);
    AdsScope.read(context).setBlocked(network.offline);
  }

  void _handleNetworkChange() {
    final offline = _network?.offline ?? false;
    final restored = _wasOffline && !offline;
    _wasOffline = offline;
    if (mounted) AdsScope.read(context).setBlocked(offline);
    if (!restored || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.tr('network.restored'))),
        );
    });
  }

  @override
  void dispose() {
    _network?.removeListener(_handleNetworkChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthScope.watch(context);
    final network = NetworkScope.watch(context);
    AdsScope.read(context).setRoute(widget.location);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth <= AppBreakpoints.mobile;
        return Scaffold(
          appBar: mobile
              ? null
              : _DesktopHeader(location: widget.location, session: session),
          body: Column(
            children: [
              if (network.offline) const NetworkStatusBanner(),
              Expanded(
                child: network.offline
                    ? MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: widget.child,
                      )
                    : widget.child,
              ),
            ],
          ),
          bottomNavigationBar: mobile
              ? _MobileTabs(
                  location: widget.location,
                  selected: _selected,
                  session: session,
                )
              : null,
        );
      },
    );
  }
}

class _DesktopHeader extends StatelessWidget implements PreferredSizeWidget {
  const _DesktopHeader({required this.location, required this.session});

  final String location;
  final AuthSessionController session;

  bool selected(String path) => path == '/'
      ? location == '/'
      : location == path || location.startsWith('$path/');

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 88,
      titleSpacing: 40,
      title: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/'),
        child: const CitizenNewsBrand(),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
      actions: [
        _HeaderLink(
          label: context.tr('nav.home'),
          path: '/',
          active: selected('/'),
        ),
        _HeaderLink(
          label: context.tr('nav.latest'),
          path: '/latest',
          active: selected('/latest'),
        ),
        _HeaderLink(
          label: context.tr('nav.explore'),
          path: '/explore',
          active: selected('/explore'),
        ),
        _HeaderLink(
          label: context.tr('nav.reporters'),
          path: '/reporters',
          active: selected('/reporters'),
        ),
        const LanguageIconButton(),
        PopupMenuButton<String>(
          tooltip: context.tr('legal.policies'),
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: context.go,
          itemBuilder: (context) => [
            for (final destination in legalDestinations)
              PopupMenuItem(
                value: destination.path,
                child: Text(context.tr(destination.translationKey)),
              ),
          ],
        ),
        const SizedBox(width: 18),
        if (session.isSignedIn)
          Tooltip(
            message: session.displayName,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.go('/account'),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.ink,
                backgroundImage: session.profile?.avatarUrl != null
                    ? NetworkImage(session.profile!.avatarUrl!)
                    : null,
                child: session.profile?.avatarUrl == null
                    ? Text(
                        session.displayName.isEmpty
                            ? 'R'
                            : session.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
            ),
          )
        else
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(context.tr('auth.login')),
          ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => context.go('/report-news'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
          child: Text(context.tr('nav.postNews')),
        ),
        const SizedBox(width: 40),
      ],
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({
    required this.label,
    required this.path,
    required this.active,
  });

  final String label;
  final String path;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(path),
      child: Container(
        height: 88,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.red : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.red : AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MobileTabs extends StatelessWidget {
  const _MobileTabs({
    required this.location,
    required this.selected,
    required this.session,
  });

  final String location;
  final bool Function(String path) selected;
  final AuthSessionController session;

  @override
  Widget build(BuildContext context) {
    final index = switch (location) {
      '/explore' => 1,
      '/report-news' => 2,
      final path when path == '/messages' || path.startsWith('/messages/') => 3,
      '/account' => 4,
      _ => 0,
    };
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (next) {
          switch (next) {
            case 0:
              context.go('/');
            case 1:
              context.go('/explore');
            case 2:
              context.go('/report-news');
            case 3:
              context.go('/messages');
            case 4:
              if (session.isSignedIn) {
                context.go('/account');
              } else {
                _showMore(context);
              }
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded, color: AppColors.red),
            label: context.tr('nav.home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            selectedIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.red,
            ),
            label: context.tr('nav.explore'),
          ),
          NavigationDestination(
            icon: const _PostNewsIcon(),
            selectedIcon: const _PostNewsIcon(selected: true),
            label: context.tr('nav.postNews'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: const Icon(
              Icons.chat_bubble_rounded,
              color: AppColors.red,
            ),
            label: context.tr('nav.chat'),
          ),
          NavigationDestination(
            icon: Icon(
              session.isSignedIn
                  ? Icons.person_outline_rounded
                  : Icons.more_horiz_rounded,
            ),
            selectedIcon: Icon(
              session.isSignedIn
                  ? Icons.person_rounded
                  : Icons.more_horiz_rounded,
              color: selected('/account') ? AppColors.red : AppColors.ink,
            ),
            label: session.isSignedIn
                ? context.tr('nav.account')
                : context.tr('nav.more'),
          ),
        ],
      ),
    );
  }

  void _showMore(BuildContext context) {
    final ads = AdsScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('nav.more'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (!session.isSignedIn) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.login_rounded),
                    title: Text(context.tr('auth.login')),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/login');
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_add_alt_1_rounded),
                    title: Text(context.tr('auth.createAccount')),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/signup');
                    },
                  ),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(context.tr('nav.reporters')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.go('/reporters');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_rounded),
                  title: Text(context.tr('language.title')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showLanguagePicker(context);
                  },
                ),
                if (ads.privacyRequired)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Ad privacy choices'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ads.showPrivacyOptions();
                    },
                  ),
                const Divider(),
                for (final destination in legalDestinations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_legalIcon(destination.path)),
                    title: Text(context.tr(destination.translationKey)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go(destination.path);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _legalIcon(String path) => switch (path) {
  '/about' => Icons.info_outline_rounded,
  '/contact' => Icons.mail_outline_rounded,
  '/privacy' => Icons.privacy_tip_outlined,
  '/copyright' => Icons.copyright_rounded,
  '/corrections-policy' => Icons.fact_check_outlined,
  '/content-removal' => Icons.remove_circle_outline_rounded,
  _ => Icons.policy_outlined,
};

class _PostNewsIcon extends StatelessWidget {
  const _PostNewsIcon({this.selected = false});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 31,
      decoration: BoxDecoration(
        color: selected ? AppColors.redDark : AppColors.red,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white),
    );
  }
}
