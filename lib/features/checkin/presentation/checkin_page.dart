import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../hosts/presentation/host_directory.dart';
import '../../hosts/presentation/host_providers.dart';
import 'checkin_form.dart';
import 'checkin_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Width at which the directory and the form sit side by side.
const kTwoPaneBreakpoint = 840.0;

class CheckinPage extends ConsumerWidget {
  const CheckinPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= kTwoPaneBreakpoint) {
        return Row(
          children: [
            Expanded(
              flex: 4,
              child: HostDirectory(
                onSelected: ref.read(checkinProvider.notifier).setHost,
              ),
            ),
            const VerticalDivider(width: 1),
            const Expanded(flex: 5, child: CheckinForm()),
          ],
        );
      }
      return CheckinForm(
        useHero: true,
        onPickHost: () => context.push('/hosts'),
      );
    });
  }
}

/// Phone-only: full-screen host directory used as a picker.
class HostPickerPage extends ConsumerWidget {
  const HostPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('hosts_title')),
        actions: [
          IconButton(
            tooltip: context.tr('retry'),
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(hostsProvider),
          ),
        ],
      ),
      body: HostDirectory(
        useHero: true,
        onSelected: (host) {
          ref.read(checkinProvider.notifier).setHost(host);
          context.pop();
        },
      ),
    );
  }
}
