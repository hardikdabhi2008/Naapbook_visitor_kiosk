import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/badge/presentation/badge_page.dart';
import 'features/checkin/presentation/checkin_page.dart';
import 'features/checkin/presentation/checkin_providers.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/settings/presentation/admin_screen.dart';
import 'features/visitors/presentation/visitors_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/checkin',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/checkin', builder: (_, _) => const CheckinPage()),
          GoRoute(path: '/visitors', builder: (_, _) => const VisitorsScreen()),
          GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
        ],
      ),
      // Full-screen routes, pushed above the shell.
      GoRoute(path: '/hosts', builder: (_, _) => const HostPickerPage()),
      GoRoute(
        path: '/badge',
        // A badge only makes sense right after a check-in (e.g. not after a
        // web reload), so bounce home otherwise.
        redirect: (_, _) =>
            ref.read(lastCheckInProvider) == null ? '/checkin' : null,
        builder: (_, _) => const BadgePage(),
      ),
    ],
  );
});
