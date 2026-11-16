import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_session_controller.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/location/presentation/explore_screen.dart';
import '../../features/legal/presentation/contact_screen.dart';
import '../../features/legal/presentation/legal_screen.dart';
import '../../features/module_placeholder/presentation/module_placeholder_screen.dart';
import '../../features/news/presentation/news_feed_screen.dart';
import '../../features/news/presentation/article_detail_screen.dart';
import '../../features/news/presentation/scoped_news_feed_screen.dart';
import '../../features/reporting/presentation/report_news_screen.dart';
import '../../features/reporter/presentation/my_stories_screen.dart';
import '../../features/reporter/presentation/article_analytics_screen.dart';
import '../../features/reporter/presentation/reporter_leaderboard_screen.dart';
import '../../features/reporter/presentation/reporter_workspace_screen.dart';
import '../../features/reporter/presentation/public_reporter_screen.dart';
import '../../features/verification/presentation/verification_screen.dart';
import '../shell/app_shell.dart';

GoRouter createAppRouter(AuthSessionController session) => GoRouter(
  initialLocation: '/',
  refreshListenable: session,
  redirect: (context, state) {
    final path = state.uri.path;
    if (session.passwordRecovery && path != '/reset-password') {
      return '/reset-password';
    }

    const protectedPrefixes = [
      '/account',
      '/settings',
      '/saved',
      '/following',
      '/comments',
      '/appeals',
      '/messages',
      '/verification',
      '/report-news',
      '/dashboard',
      '/my-stories',
      '/points',
      '/wallet',
      '/analytics',
      '/admin',
    ];
    final protected = protectedPrefixes.any(
      (prefix) => path == prefix || path.startsWith('$prefix/'),
    );
    if (session.configured && !session.isSignedIn && protected) {
      return Uri(
        path: '/login',
        queryParameters: {'returnTo': state.uri.toString()},
      ).toString();
    }

    const guestOnly = {
      '/welcome',
      '/login',
      '/signup',
      '/otp',
      '/forgot-password',
    };
    if (session.isSignedIn && guestOnly.contains(path)) return '/';
    if (session.isSignedIn && session.authorizationReady) {
      const suspendedRestrictedPrefixes = [
        '/report-news',
        '/dashboard',
        '/my-stories',
        '/points',
        '/wallet',
        '/analytics',
        '/admin',
        '/messages',
      ];
      final suspendedRestricted = suspendedRestrictedPrefixes.any(
        (prefix) => path == prefix || path.startsWith('$prefix/'),
      );
      if (session.isSuspended && suspendedRestricted) return '/account';
      const reporterPrefixes = [
        '/report-news',
        '/dashboard',
        '/my-stories',
        '/points',
        '/wallet',
        '/analytics',
      ];
      final reporterOnly = reporterPrefixes.any(
        (prefix) => path == prefix || path.startsWith('$prefix/'),
      );
      if (reporterOnly && !session.isReporter) return '/verification';
      if ((path == '/admin' || path.startsWith('/admin/')) &&
          !session.isAdmin) {
        return '/account';
      }
    }
    return null;
  },
  errorBuilder: (context, state) => const ModulePlaceholderScreen(
    eyebrow: 'NOT FOUND',
    title: 'This page does not exist',
    description: 'Return to the CitizenNews home page and continue browsing.',
    icon: Icons.travel_explore_rounded,
  ),
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const NewsFeedScreen()),
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => AuthScreen(
            mode: AuthMode.login,
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const AuthScreen(mode: AuthMode.signup),
        ),
        GoRoute(
          path: '/otp',
          builder: (context, state) => AuthScreen(
            mode: AuthMode.otp,
            initialEmail: state.uri.queryParameters['email'] ?? '',
          ),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) =>
              const AuthScreen(mode: AuthMode.forgotPassword),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) =>
              const AuthScreen(mode: AuthMode.resetPassword),
        ),
        GoRoute(
          path: '/latest',
          builder: (context, state) =>
              const NewsFeedScreen(initialTab: 'latest'),
        ),
        GoRoute(
          path: '/trending',
          builder: (context, state) =>
              const NewsFeedScreen(initialTab: 'trending'),
        ),
        GoRoute(
          path: '/world',
          builder: (context, state) =>
              const NewsFeedScreen(initialTab: 'worldwide'),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) =>
              const NewsFeedScreen(initialTab: 'latest'),
        ),
        GoRoute(
          path: '/news/:slug',
          builder: (context, state) =>
              ArticleDetailScreen(slug: state.pathParameters['slug'] ?? ''),
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExploreScreen(),
        ),
        GoRoute(
          path: '/reporters',
          builder: (context, state) => const ReporterLeaderboardScreen(),
        ),
        GoRoute(
          path: '/report-news',
          builder: (context, state) => const ReportNewsScreen(),
        ),
        GoRoute(
          path: '/my-stories',
          builder: (context, state) => const MyStoriesScreen(),
        ),
        GoRoute(path: '/my-news', redirect: (context, state) => '/my-stories'),
        GoRoute(
          path: '/messages',
          builder: (context, state) => const ChatScreen(),
        ),
        GoRoute(
          path: '/account',
          builder: (context, state) => const AccountScreen(),
        ),
        GoRoute(path: '/profile', redirect: (context, state) => '/account'),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const AccountScreen(mode: AccountMode.settings),
        ),
        GoRoute(
          path: '/saved',
          builder: (context, state) =>
              const AccountScreen(mode: AccountMode.saved),
        ),
        GoRoute(
          path: '/following',
          builder: (context, state) =>
              const AccountScreen(mode: AccountMode.following),
        ),
        GoRoute(
          path: '/comments',
          builder: (context, state) =>
              const AccountScreen(mode: AccountMode.comments),
        ),
        GoRoute(
          path: '/appeals',
          builder: (context, state) =>
              const AccountScreen(mode: AccountMode.appeals),
        ),
        GoRoute(
          path: '/verification',
          builder: (context, state) => const VerificationScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => AdminScreen(
            initialTab: state.uri.queryParameters['tab'] ?? 'overview',
          ),
        ),
        for (final legalPage in const [
          'terms',
          'privacy',
          'community-guidelines',
          'about',
          'editorial-policy',
          'corrections-policy',
          'content-removal',
          'copyright',
        ])
          GoRoute(
            path: '/$legalPage',
            builder: (context, state) => LegalScreen(
              key: ValueKey(state.uri.toString()),
              page: legalPage,
            ),
          ),
        GoRoute(
          path: '/contact',
          builder: (context, state) => const ContactScreen(),
        ),
        for (final mode in const ['dashboard', 'points', 'wallet'])
          GoRoute(
            path: '/$mode',
            builder: (context, state) => ReporterWorkspaceScreen(mode: mode),
          ),
        GoRoute(
          path: '/messages/:peer',
          builder: (context, state) => ChatScreen(
            key: ValueKey(state.uri.toString()),
            initialPeerId: state.pathParameters['peer'],
          ),
        ),
        GoRoute(
          path: '/report-news/edit/:id',
          builder: (context, state) =>
              ReportNewsScreen(postId: state.pathParameters['id']),
        ),
        GoRoute(
          path: '/analytics/:id',
          builder: (context, state) =>
              ArticleAnalyticsScreen(postId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/country/:slug',
          builder: (context, state) => ScopedNewsFeedScreen(
            key: ValueKey(state.uri.toString()),
            kind: ScopedFeedKind.country,
            slug: state.pathParameters['slug'] ?? '',
          ),
        ),
        GoRoute(
          path: '/region/:countrySlug/:slug',
          builder: (context, state) => ScopedNewsFeedScreen(
            key: ValueKey(state.uri.toString()),
            kind: ScopedFeedKind.region,
            countrySlug: state.pathParameters['countrySlug'] ?? '',
            slug: state.pathParameters['slug'] ?? '',
          ),
        ),
        GoRoute(
          path: '/city/:countrySlug/:slug',
          builder: (context, state) => ScopedNewsFeedScreen(
            key: ValueKey(state.uri.toString()),
            kind: ScopedFeedKind.city,
            countrySlug: state.pathParameters['countrySlug'] ?? '',
            slug: state.pathParameters['slug'] ?? '',
          ),
        ),
        GoRoute(
          path: '/category/:slug',
          builder: (context, state) => ScopedNewsFeedScreen(
            key: ValueKey(state.uri.toString()),
            kind: ScopedFeedKind.category,
            slug: state.pathParameters['slug'] ?? '',
          ),
        ),
        GoRoute(
          path: '/reporter/:username',
          builder: (context, state) => PublicReporterScreen(
            key: ValueKey(state.uri.toString()),
            username: state.pathParameters['username'] ?? '',
          ),
        ),
      ],
    ),
  ],
);
