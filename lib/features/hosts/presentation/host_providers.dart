import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../checkin/presentation/checkin_providers.dart';
import '../../visitors/domain/visitor.dart';
import '../../visitors/presentation/visitor_providers.dart';
import '../data/host_repository_impl.dart';
import '../domain/host.dart';

final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => HostRepositoryImpl(ref.watch(dioProvider)),
);

final hostsProvider = FutureProvider<List<Host>>(
  (ref) => ref.watch(hostRepositoryProvider).fetchHosts(),
);

/// Ids of hosts who currently have a visitor checked in from this kiosk.
///
/// The API's `available` flag is fixed seed data (nothing can change it), so
/// the kiosk tracks "busy with a visitor" itself: a host shows as Unavailable
/// from check-in until that visitor is checked out. It lives in memory, like the
/// list of recent check-ins it is derived from, so it resets on an app restart.
final busyHostIdsProvider = Provider<Set<String>>((ref) => {
      for (final v in ref.watch(recentCheckInsProvider))
        if (v.status == VisitorStatus.checkedIn) v.hostId,
    });

/// True when the host currently chosen in the check-in form cannot be visited:
/// the API says they are unavailable, or they already have a visitor checked in
/// from this kiosk. Watching it also loads the host list (the form may be showing
/// a host restored from a saved draft before the directory was ever opened).
final selectedHostUnavailableProvider = Provider<bool>((ref) {
  final id = ref.watch(checkinProvider.select((d) => d.hostId));
  if (id == null) return false;
  if (ref.watch(busyHostIdsProvider).contains(id)) return true;
  final hosts = ref.watch(hostsProvider).value;
  if (hosts == null) return false;
  for (final h in hosts) {
    if (h.id == id) return !h.available;
  }
  return false;
});

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
