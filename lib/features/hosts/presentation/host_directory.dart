import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/highlighted_text.dart';
import '../../../core/widgets/state_views.dart';
import '../../checkin/presentation/checkin_providers.dart';
import '../domain/host.dart';
import 'host_providers.dart';

String hostHeroTag(String id) => 'host-avatar-$id';

/// Searchable list of hosts. [onSelected] is called when a row is tapped.
///
/// [useHero] is off in the side-by-side layout: both ends of the transition
/// would live on the same page and Flutter forbids duplicate Hero tags there.
class HostDirectory extends ConsumerStatefulWidget {
  const HostDirectory({super.key, required this.onSelected, this.useHero = false});

  final ValueChanged<Host> onSelected;
  final bool useHero;

  @override
  ConsumerState<HostDirectory> createState() => _HostDirectoryState();
}

class _HostDirectoryState extends ConsumerState<HostDirectory> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(hostQueryProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppConfig.searchDebounce, () {
      if (mounted) ref.read(hostQueryProvider.notifier).set(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(hostQueryProvider.notifier).set('');
  }

  @override
  Widget build(BuildContext context) {
    // The search field lives here and does NOT watch the filtered list, so
    // typing rebuilds only the results subtree below.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: context.tr('search_hosts'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('clear_search'),
                        icon: const Icon(Icons.clear),
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
        ),
        Expanded(child: _Results(onSelected: widget.onSelected, useHero: widget.useHero)),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.onSelected, required this.useHero});

  final ValueChanged<Host> onSelected;
  final bool useHero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filteredHostsProvider);
    final query = ref.watch(hostQueryProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(hostsProvider)),
      data: (hosts) {
        if (hosts.isEmpty) {
          return StateMessage(icon: Icons.person_search, message: context.tr('no_hosts'));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.tr('host_count', {'n': hosts.length}),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: hosts.length,
                itemBuilder: (context, i) => HostTile(
                  key: ValueKey(hosts[i].id),
                  host: hosts[i],
                  query: query,
                  useHero: useHero,
                  onTap: () => onSelected(hosts[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single row. It watches only "is this host selected?" so choosing a host
/// rebuilds two rows, not all 500.
class HostTile extends ConsumerWidget {
  const HostTile({
    super.key,
    required this.host,
    required this.query,
    required this.onTap,
    required this.useHero,
  });

  final Host host;
  final String query;
  final VoidCallback onTap;
  final bool useHero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(checkinProvider.select((d) => d.hostId == host.id));
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;

    Widget avatar = CircleAvatar(
      backgroundColor: selected ? scheme.primary : scheme.secondaryContainer,
      foregroundColor: selected ? scheme.onPrimary : scheme.onSecondaryContainer,
      child: Text(host.initials),
    );
    if (useHero) avatar = Hero(tag: hostHeroTag(host.id), child: avatar);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: avatar),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightedText(host.name, query: query, style: theme.titleMedium),
                    Wrap(
                      spacing: 6,
                      children: [
                        Text('${host.designation} ·', style: theme.bodyMedium),
                        HighlightedText(host.department,
                            query: query, style: theme.bodyMedium),
                      ],
                    ),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(context.tr('floor_label', {'f': host.floor}),
                            style: theme.bodySmall),
                        _Availability(available: host.available),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Availability extends StatelessWidget {
  const _Availability({required this.available});
  final bool available;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = available ? scheme.primary : scheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(available ? Icons.check_circle : Icons.do_not_disturb_on,
            size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          context.tr(available ? 'available' : 'unavailable'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
