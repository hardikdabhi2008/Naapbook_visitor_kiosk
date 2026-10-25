import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/visitor.dart';
import 'visitor_providers.dart';

class VisitorsScreen extends ConsumerStatefulWidget {
  const VisitorsScreen({super.key});

  @override
  ConsumerState<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends ConsumerState<VisitorsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 600) {
        ref.read(visitorsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await ref.read(visitorsProvider.notifier).refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('refresh_failed'))));
      }
    }
  }

  /// Hides the row, offers Undo, and only calls the API if Undo is not tapped.
  void _checkOut(Visitor v) {
    final notifier = ref.read(visitorsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final failedText = context.tr('checkout_failed', {'name': v.name});
    final doneText = context.tr('checked_out_snack', {'name': v.name});
    final undoText = context.tr('undo');

    final index = notifier.stageCheckOut(v);
    messenger.hideCurrentSnackBar(); // commits the previous one immediately
    messenger
        .showSnackBar(SnackBar(
          content: Text(doneText),
          duration: AppConfig.undoWindow,
          persist: false,
          action: SnackBarAction(
            label: undoText,
            onPressed: () => notifier.undoCheckOut(v, index),
          ),
        ))
        .closed
        .then((reason) async {
      if (reason == SnackBarClosedReason.action) return;
      try {
        await notifier.commitCheckOut(v, index);
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(failedText)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(visitorsProvider);
    final filter = ref.watch(visitorFilterProvider);
    final purposes = {
      for (final p in ref.watch(purposesProvider).value ?? const <Purpose>[])
        p.id: p.label,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              header: true,
              child: Text(context.tr('visitors_title'),
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 8,
              children: [
                _FilterChip(
                    label: context.tr('filter_all'),
                    selected: filter == null,
                    onTap: () => ref.read(visitorFilterProvider.notifier).set(null)),
                for (final s in VisitorStatus.values)
                  _FilterChip(
                    label: context.tr(statusKey(s)),
                    selected: filter == s,
                    onTap: () => ref.read(visitorFilterProvider.notifier).set(s),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) =>
                  ErrorView(error: e, onRetry: () => ref.invalidate(visitorsProvider)),
              data: (s) {
                if (s.items.isEmpty) {
                  return StateMessage(
                      icon: Icons.groups_outlined, message: context.tr('no_visitors'));
                }
                return ListView.builder(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: s.items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == s.items.length) return _Footer(state: s);
                    final v = s.items[i];
                    return VisitorTile(
                      key: ValueKey(v.id),
                      visitor: v,
                      purposeLabel: purposes[v.purposeId] ?? v.purposeId,
                      onCheckOut: () => _checkOut(v),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

String statusKey(VisitorStatus s) => switch (s) {
      VisitorStatus.checkedIn => 'status_checked_in',
      VisitorStatus.checkedOut => 'status_checked_out',
      VisitorStatus.expected => 'status_expected',
    };

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state});
  final VisitorsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: StateMessageInline(
          message: context.tr('load_more_failed'),
          onRetry: () => ref.read(visitorsProvider.notifier).loadMore(),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class StateMessageInline extends StatelessWidget {
  const StateMessageInline({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(message),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('retry')),
          ),
        ],
      );
}

class VisitorTile extends StatelessWidget {
  const VisitorTile({
    super.key,
    required this.visitor,
    required this.purposeLabel,
    required this.onCheckOut,
  });

  final Visitor visitor;
  final String purposeLabel;
  final VoidCallback onCheckOut;

  String _time(BuildContext context, DateTime? d) => d == null
      ? ''
      : DateFormat.jm(Localizations.localeOf(context).toString()).format(d);

  @override
  Widget build(BuildContext context) {
    final v = visitor;
    final theme = Theme.of(context).textTheme;
    final times = switch (v.status) {
      VisitorStatus.checkedIn => _time(context, v.checkInAt),
      VisitorStatus.checkedOut =>
        '${_time(context, v.checkInAt)} → ${_time(context, v.checkOutAt)}',
      VisitorStatus.expected => _time(context, v.expectedAt),
    };

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name, style: theme.titleMedium),
                Text(
                  [if ((v.company ?? '').isNotEmpty) v.company!, purposeLabel].join(' · '),
                  style: theme.bodyMedium,
                ),
                Text(v.hostName, style: theme.bodySmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(status: v.status),
                    if (times.isNotEmpty) Text(times, style: theme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          // Swipe is not reachable with TalkBack, so offer the same action as
          // a labelled button.
          if (v.canCheckOut)
            IconButton(
              tooltip: '${context.tr('checkout')}: ${v.name}',
              onPressed: onCheckOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
    );

    if (!v.canCheckOut) return Column(children: [content, const Divider(height: 1)]);

    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismiss-${v.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onCheckOut(),
      background: Container(
        color: scheme.primaryContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(context.tr('checkout'),
                  style: TextStyle(color: scheme.onPrimaryContainer)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.logout, color: scheme.onPrimaryContainer),
          ],
        ),
      ),
      child: Column(children: [content, const Divider(height: 1)]),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final VisitorStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (status) {
      VisitorStatus.checkedIn =>
        (scheme.primaryContainer, scheme.onPrimaryContainer, Icons.login),
      VisitorStatus.checkedOut =>
        (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Icons.logout),
      VisitorStatus.expected =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer, Icons.schedule),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(context.tr(statusKey(status)),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}
