import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';

class _Dest {
  const _Dest(this.path, this.icon, this.labelKey);
  final String path;
  final IconData icon;
  final String labelKey;
}

const _dests = [
  _Dest('/checkin', Icons.how_to_reg, 'nav_checkin'),
  _Dest('/visitors', Icons.groups, 'nav_visitors'),
  _Dest('/admin', Icons.admin_panel_settings, 'nav_admin'),
];

/// Bottom bar on phones, side rail on tablets and web. Content is capped at
/// 1200dp so wide web windows stay readable.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = _dests.indexWhere((d) => location.startsWith(d.path)).clamp(0, 2);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 600;
    void go(int i) => context.go(_dests[i].path);

    final body = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      ),
    );

    if (!wide) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: go,
          destinations: [
            for (final d in _dests)
              NavigationDestination(icon: Icon(d.icon), label: context.tr(d.labelKey)),
          ],
        ),
      );
    }

    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              minWidth: 88 * scale.clamp(1.0, 2.0),
              destinations: [
                for (final d in _dests)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(context.tr(d.labelKey), textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
