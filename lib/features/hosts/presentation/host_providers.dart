import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/host_repository_impl.dart';
import '../domain/host.dart';

final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => HostRepositoryImpl(ref.watch(dioProvider)),
);

final hostsProvider = FutureProvider<List<Host>>(
  (ref) => ref.watch(hostRepositoryProvider).fetchHosts(),
);

/// The debounced, committed search text.
class HostQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final hostQueryProvider =
    NotifierProvider<HostQuery, String>(HostQuery.new);

/// Derived list. Only widgets that watch this rebuild when the query changes;
/// the search field itself is outside it.
final filteredHostsProvider = Provider<AsyncValue<List<Host>>>((ref) {
  final q = ref.watch(hostQueryProvider).trim().toLowerCase();
  return ref.watch(hostsProvider).whenData((hosts) => q.isEmpty
      ? hosts
      : hosts
          .where((h) =>
              h.name.toLowerCase().contains(q) ||
              h.department.toLowerCase().contains(q))
          .toList(growable: false));
});
