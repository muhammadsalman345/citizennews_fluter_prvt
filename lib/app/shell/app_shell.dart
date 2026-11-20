import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/ads/ads_scope.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/language_picker.dart';
import '../../core/localization/localization_scope.dart';
import '../../core/network/network_controller.dart';
import '../../core/network/network_scope.dart';
import '../../core/network/network_status_banner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/presentation/auth_scope.dart';

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
  bool _mobileTabsVisible = true;
  DateTime? _lastRootBackAt;

  bool get _handlesAndroidSystemBack =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _selected(String path) => path == '/'
      ? widget.location == '/'
      : widget.location == path || widget.location.startsWith('$path/');

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _lastRootBackAt = null;
      _mobileTabsVisible = true;
    }
  }

  bool _handleHomeScroll(UserScrollNotification notification) {
    if (widget.location != '/' || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final visible = switch (notification.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _mobileTabsVisible,
    };
    if (visible != _mobileTabsVisible) {
      setState(() => _mobileTabsVisible = visible);
    }
    return false;
  }

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
        ..showSnackBar(SnackBar(content: Text(context.tr('network.restored'))));
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
    final router = GoRouter.of(context);
    final destination = AppNavigation.destinationFor(widget.location);
    AdsScope.read(context).setRoute(widget.location);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth <= AppBreakpoints.mobile;
        return PopScope<Object?>(
          canPop: router.canPop() || !_handlesAndroidSystemBack,
          onPopInvokedWithResult: _handleSystemBack,
          child: Scaffold(
            appBar: mobile
                ? destination.showMobileTopBar
                      ? _MobilePageHeader(destination: destination)
                      : null
                : destination.showDesktopNavigation
                ? _DesktopHeader(location: widget.location, session: session)
                : null,
            body: Column(
              children: [
                if (network.offline) const NetworkStatusBanner(),
                Expanded(
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: _handleHomeScroll,
                    child: network.offline
                        ? MediaQuery.removePadding(
                            context: context,
                            removeTop: true,
                            child: widget.child,
                          )
                        : widget.child,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: mobile && destination.showBottomNavigation
                ? _AnimatedMobileTabs(
                    visible: widget.location != '/' || _mobileTabsVisible,
                    child: _MobileTabs(
                      location: widget.location,
                      selected: _selected,
                      session: session,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _handleSystemBack(bool didPop, Object? result) {
    if (didPop || !mounted) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    final destination = AppNavigation.destinationFor(widget.location);
    if (!destination.isPrimaryRoot) {
      router.go(destination.fallback);
      return;
    }
    if (widget.location != AppNavigation.home) {
      router.go(AppNavigation.home);
      return;
    }

    final now = DateTime.now();
    final previous = _lastRootBackAt;
    if (previous != null &&
        now.difference(previous) <= const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastRootBackAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
  }
}

class _AnimatedMobileTabs extends StatelessWidget {
  const _AnimatedMobileTabs({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: value,
          child: IgnorePointer(
            ignoring: !visible,
            child: Opacity(opacity: value, child: child),
          ),
        ),
      ),
    );
  }
}

class _MobilePageHeader extends StatelessWidget implements PreferredSizeWidget {
  const _MobilePageHeader({required this.destination});

  final AppDestination destination;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.backOr(destination.fallback),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      titleSpacing: 0,
      title: Text(
        destination.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
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
    final destination = AppNavigation.destinationFor(location);
    return AppBar(
      toolbarHeight: 88,
      titleSpacing: 40,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (destination.showMobileTopBar) ...[
            IconButton(
              tooltip: 'Back',
              onPressed: () => context.backOr(destination.fallback),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go('/'),
            child: const CitizenNewsBrand(),
          ),
        ],
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
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: AppColors.ink.withValues(alpha: .58),
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .88,
        child: _GuestMoreSheet(
          showAdPrivacy: ads.privacyRequired,
          onLogin: () {
            Navigator.pop(sheetContext);
            context.go('/login');
          },
          onCreateAccount: () {
            Navigator.pop(sheetContext);
            context.go('/signup');
          },
          onReporters: () {
            Navigator.pop(sheetContext);
            context.go('/reporters');
          },
          onLanguage: () {
            Navigator.pop(sheetContext);
            showLanguagePicker(context);
          },
          onAbout: () {
            Navigator.pop(sheetContext);
            context.go('/about');
          },
          onAdPrivacy: () {
            Navigator.pop(sheetContext);
            ads.showPrivacyOptions();
          },
        ),
      ),
    );
  }
}

class _GuestMoreSheet extends StatelessWidget {
  const _GuestMoreSheet({
    required this.showAdPrivacy,
    required this.onLogin,
    required this.onCreateAccount,
    required this.onReporters,
    required this.onLanguage,
    required this.onAbout,
    required this.onAdPrivacy,
  });

  final bool showAdPrivacy;
  final VoidCallback onLogin;
  final VoidCallback onCreateAccount;
  final VoidCallback onReporters;
  final VoidCallback onLanguage;
  final VoidCallback onAbout;
  final VoidCallback onAdPrivacy;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('nav.more'),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _GuestWelcomeCard(),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login_rounded),
                label: Text(context.tr('auth.login')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onCreateAccount,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(context.tr('auth.createAccount')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  side: const BorderSide(color: AppColors.muted),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              const _MoreSectionLabel(label: 'EXPLORE CITIZENNEWS'),
              const SizedBox(height: 9),
              _MoreMenuCard(
                children: [
                  _MoreMenuRow(
                    icon: Icons.groups_2_outlined,
                    title: context.tr('nav.reporters'),
                    subtitle: 'Meet trusted community reporters',
                    onTap: onReporters,
                  ),
                  _MoreMenuRow(
                    icon: Icons.language_rounded,
                    title: context.tr('language.title'),
                    subtitle: 'Choose your language and reading direction',
                    trailing: LocalizationScope.watch(context).language.nativeName,
                    onTap: onLanguage,
                  ),
                  _MoreMenuRow(
                    icon: Icons.info_outline_rounded,
                    title: 'About CitizenNews',
                    subtitle: 'Our mission, standards and policies',
                    onTap: onAbout,
                  ),
                  if (showAdPrivacy)
                    _MoreMenuRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Ad privacy choices',
                      subtitle: 'Review your advertising preferences',
                      onTap: onAdPrivacy,
                    ),
                ],
              ),
              const SizedBox(height: 22),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.newspaper_rounded, size: 16, color: AppColors.red),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'CitizenNews  •  News from your community',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _GuestWelcomeCard extends StatelessWidget {
  const _GuestWelcomeCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFDADD)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(17),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.red,
                size: 30,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stay connected',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 21,
                        ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Log in to follow reporters, save stories and join conversations.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MoreSectionLabel extends StatelessWidget {
  const _MoreSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.25,
        ),
      );
}

class _MoreMenuCard extends StatelessWidget {
  const _MoreMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A152431),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                const Divider(height: 1, indent: 72),
            ],
          ],
        ),
      );
}

class _MoreMenuRow extends StatelessWidget {
  const _MoreMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.ink, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 78),
                  child: Text(
                    trailing!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 22,
              ),
            ],
          ),
        ),
      );
}

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
