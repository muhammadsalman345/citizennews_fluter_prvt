import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Central navigation rules for the mobile application.
///
/// Root destinations replace the selected application section. Content and
/// detail destinations should be pushed so Android back restores the exact
/// screen and scroll position the user came from.
abstract final class AppNavigation {
  static const home = '/';
  static const explore = '/explore';
  static const reportNews = '/report-news';
  static const messages = '/messages';
  static const account = '/account';

  static const primaryRoots = {home, explore, reportNews, messages, account};

  static AppDestination destinationFor(String location) {
    final path = Uri.tryParse(location)?.path ?? location;

    final exact = switch (path) {
      '/' => const AppDestination.root(title: 'Home'),
      '/explore' => const AppDestination.root(title: 'Explore'),
      '/report-news' => const AppDestination.root(title: 'Post news'),
      '/messages' => const AppDestination.root(title: 'Messages'),
      '/account' => const AppDestination.root(title: 'Account'),
      '/latest' => const AppDestination.browse(title: 'Latest news'),
      '/trending' => const AppDestination.browse(title: 'Trending'),
      '/world' => const AppDestination.browse(title: 'World news'),
      '/search' => const AppDestination.browse(title: 'Search'),
      '/reporters' => const AppDestination.browse(title: 'Reporters'),
      '/welcome' => const AppDestination.immersive(title: 'Welcome'),
      '/login' => const AppDestination.immersive(title: 'Sign in'),
      '/signup' => const AppDestination.immersive(title: 'Create account'),
      '/otp' => const AppDestination.immersive(title: 'Verify account'),
      '/forgot-password' => const AppDestination.immersive(
        title: 'Forgot password',
      ),
      '/reset-password' => const AppDestination.immersive(
        title: 'Reset password',
      ),
      '/settings' => const AppDestination.child(
        title: 'Settings',
        fallback: account,
      ),
      '/saved' => const AppDestination.child(
        title: 'Saved stories',
        fallback: account,
      ),
      '/following' => const AppDestination.child(
        title: 'Following',
        fallback: account,
      ),
      '/comments' => const AppDestination.child(
        title: 'Your comments',
        fallback: account,
      ),
      '/appeals' => const AppDestination.child(
        title: 'Appeals',
        fallback: account,
      ),
      '/verification' => const AppDestination.child(
        title: 'Reporter verification',
        fallback: account,
      ),
      '/admin' => const AppDestination.child(
        title: 'Administration',
        fallback: account,
      ),
      '/dashboard' => const AppDestination.child(
        title: 'Reporter dashboard',
        fallback: account,
      ),
      '/points' => const AppDestination.child(
        title: 'Points',
        fallback: '/dashboard',
      ),
      '/wallet' => const AppDestination.child(
        title: 'Wallet',
        fallback: '/dashboard',
      ),
      '/my-stories' => const AppDestination.child(
        title: 'My stories',
        fallback: '/dashboard',
      ),
      '/contact' => const AppDestination.child(title: 'Contact CitizenNews'),
      '/terms' => const AppDestination.child(title: 'Terms'),
      '/privacy' => const AppDestination.child(title: 'Privacy'),
      '/community-guidelines' => const AppDestination.child(
        title: 'Community guidelines',
      ),
      '/about' => const AppDestination.child(title: 'About CitizenNews'),
      '/editorial-policy' => const AppDestination.child(
        title: 'Editorial policy',
      ),
      '/corrections-policy' => const AppDestination.child(
        title: 'Corrections policy',
      ),
      '/content-removal' => const AppDestination.child(
        title: 'Content removal',
      ),
      '/copyright' => const AppDestination.child(title: 'Copyright'),
      _ => null,
    };
    if (exact != null) return exact;

    if (path.startsWith('/news/')) {
      return const AppDestination.child(title: 'Story');
    }
    if (path.startsWith('/messages/')) {
      return const AppDestination.child(
        title: 'Conversation',
        fallback: messages,
      );
    }
    if (path.startsWith('/report-news/edit/')) {
      return const AppDestination.child(
        title: 'Edit story',
        fallback: '/my-stories',
      );
    }
    if (path.startsWith('/analytics/')) {
      return const AppDestination.child(
        title: 'Story analytics',
        fallback: '/my-stories',
      );
    }
    if (path.startsWith('/reporter/')) {
      return const AppDestination.child(
        title: 'Reporter profile',
        fallback: '/reporters',
      );
    }
    if (path.startsWith('/country/')) {
      return const AppDestination.browse(
        title: 'Country news',
        fallback: explore,
      );
    }
    if (path.startsWith('/region/')) {
      return const AppDestination.browse(
        title: 'Regional news',
        fallback: explore,
      );
    }
    if (path.startsWith('/city/')) {
      return const AppDestination.browse(title: 'City news', fallback: explore);
    }
    if (path.startsWith('/category/')) {
      return const AppDestination.browse(
        title: 'Category news',
        fallback: explore,
      );
    }

    return const AppDestination.child(title: 'CitizenNews');
  }
}

class AppDestination {
  const AppDestination._({
    required this.title,
    required this.fallback,
    required this.isPrimaryRoot,
    required this.showMobileTopBar,
    required this.showBottomNavigation,
    required this.showDesktopNavigation,
  });

  const AppDestination.root({required String title})
    : this._(
        title: title,
        fallback: AppNavigation.home,
        isPrimaryRoot: true,
        showMobileTopBar: false,
        showBottomNavigation: true,
        showDesktopNavigation: true,
      );

  const AppDestination.browse({
    required String title,
    String fallback = AppNavigation.home,
  }) : this._(
         title: title,
         fallback: fallback,
         isPrimaryRoot: false,
         showMobileTopBar: true,
         showBottomNavigation: true,
         showDesktopNavigation: true,
       );

  const AppDestination.child({
    required String title,
    String fallback = AppNavigation.home,
  }) : this._(
         title: title,
         fallback: fallback,
         isPrimaryRoot: false,
         showMobileTopBar: true,
         showBottomNavigation: false,
         showDesktopNavigation: true,
       );

  const AppDestination.immersive({required String title})
    : this._(
        title: title,
        fallback: AppNavigation.home,
        isPrimaryRoot: false,
        showMobileTopBar: false,
        showBottomNavigation: false,
        showDesktopNavigation: false,
      );

  final String title;
  final String fallback;
  final bool isPrimaryRoot;
  final bool showMobileTopBar;
  final bool showBottomNavigation;
  final bool showDesktopNavigation;
}

extension AppNavigationContext on BuildContext {
  /// Switches a primary application section without stacking duplicate roots.
  void goToRoot(String location) => go(location);

  /// Opens content above the current screen so system back restores context.
  Future<T?> openPage<T extends Object?>(String location) => push<T>(location);

  /// Pops when history exists, otherwise uses the route's logical parent.
  void backOr(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }

  void backToLogicalParent() {
    final router = GoRouter.of(this);
    final location = router.routerDelegate.currentConfiguration.uri.toString();
    backOr(AppNavigation.destinationFor(location).fallback);
  }
}
