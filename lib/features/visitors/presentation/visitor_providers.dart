import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../data/visitor_repository_impl.dart';
import '../domain/usecases.dart';
import '../domain/visitor.dart';

final visitorRepositoryProvider = Provider<VisitorRepository>(
  (ref) => VisitorRepositoryImpl(ref.watch(dioProvider)),
);

final submitCheckInProvider = Provider<SubmitCheckIn>(
  (ref) => SubmitCheckIn(ref.watch(visitorRepositoryProvider)),
);

final checkOutVisitorProvider = Provider<CheckOutVisitor>(
  (ref) => CheckOutVisitor(ref.watch(visitorRepositoryProvider)),
);

/// The purpose dropdown's options. The form is unusable without them, and this is
/// a plain GET (safe to repeat), so a transient failure — the API fails ~5% of
/// calls on purpose, or the connection blips — is retried quietly up to 3 times
/// before the field shows its error with a Retry button.
final purposesProvider = FutureProvider<List<Purpose>>((ref) async {
  final repo = ref.watch(visitorRepositoryProvider);
  for (var attempt = 1;; attempt++) {
    try {
      return await repo.fetchPurposes();
    } catch (e) {
      final kind = ApiException.from(e).kind;
      final transient = kind == FailureKind.server ||
          kind == FailureKind.network ||
          kind == FailureKind.timeout;
      if (attempt >= 3 || !transient || !ref.mounted) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
    }
  }
});

/// Visitors checked in from this kiosk, newest first.
///
/// The API lists visitors by their time, and a day's data can contain later
/// times than "now", so a fresh check-in may land pages down the list and look
/// as if it was never saved. These are kept on top of Today's visitors instead
/// (and de-duplicated if the server page also contains them).
class RecentCheckIns extends Notifier<List<Visitor>> {
  @override
  List<Visitor> build() => const [];

  void add(Visitor v) => state = [v, ...state.where((x) => x.id != v.id)];

  /// Keeps the pinned copy in step after a check-out.
  void update(Visitor v) =>
      state = [for (final x in state) x.id == v.id ? v : x];
}

final recentCheckInsProvider =
    NotifierProvider<RecentCheckIns, List<Visitor>>(RecentCheckIns.new);

class VisitorFilter extends Notifier<VisitorStatus?> {
  @override
  VisitorStatus? build() => null;

  void set(VisitorStatus? s) => state = s;
}

final visitorFilterProvider =
    NotifierProvider<VisitorFilter, VisitorStatus?>(VisitorFilter.new);

class VisitorsState {
  const VisitorsState({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Visitor> items;
  final String? nextCursor;
  final bool loadingMore;
  final bool loadMoreFailed;

  VisitorsState copyWith({
    List<Visitor>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) =>
      VisitorsState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// Cursor-paged list of today's visitors.
///
/// Changing the filter re-runs [build], which Riverpod treats as a fresh load
/// (previous in-flight results are discarded, so a slow response for an old
/// filter can never overwrite a newer one).
class VisitorsController extends AsyncNotifier<VisitorsState> {
  @override
  Future<VisitorsState> build() async {
    final filter = ref.watch(visitorFilterProvider);
    final page = await ref
        .read(visitorRepositoryProvider)
        .fetchVisitors(status: filter);
    return VisitorsState(
        items: _withRecent(page.items, filter), nextCursor: page.nextCursor);
  }

  /// Puts this kiosk's own check-ins (matching the status filter) on top.
  List<Visitor> _withRecent(List<Visitor> pageItems, VisitorStatus? filter) {
    final recent = [
      for (final v in ref.read(recentCheckInsProvider))
        if (filter == null || v.status == filter) v,
    ];
    if (recent.isEmpty) return pageItems;
    final ids = {for (final v in recent) v.id};
    return [...recent, ...pageItems.where((v) => !ids.contains(v.id))];
  }

  /// Pull-to-refresh. On failure the current list is kept and the error is
  /// rethrown for the caller to show.
  Future<void> refresh() async {
    final filter = ref.read(visitorFilterProvider);
    final page = await ref
        .read(visitorRepositoryProvider)
        .fetchVisitors(status: filter);
    if (ref.read(visitorFilterProvider) != filter) return;
    state = AsyncData(VisitorsState(
        items: _withRecent(page.items, filter), nextCursor: page.nextCursor));
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.loadingMore || s.nextCursor == null) return;
    final filter = ref.read(visitorFilterProvider);
    state = AsyncData(s.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await ref
          .read(visitorRepositoryProvider)
          .fetchVisitors(status: filter, cursor: s.nextCursor);
      if (ref.read(visitorFilterProvider) != filter) return;
      final cur = state.value!;
      final known = cur.items.map((v) => v.id).toSet();
      final fresh = page.items.where((v) => !known.contains(v.id));
      state = AsyncData(cur.copyWith(
        items: [...cur.items, ...fresh],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        loadingMore: false,
      ));
    } catch (_) {
      if (ref.read(visitorFilterProvider) != filter) return;
      state = AsyncData(state.value!.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  // --- Check-out with undo -------------------------------------------------
  // The API has no undo, so check-out is two-phase and the server is only
  // called once the undo window closes:
  //   1. stageCheckOut  - hide the row locally (nothing sent)
  //   2a. undoCheckOut   - put it back (nothing was ever sent)
  //   2b. commitCheckOut - POST /checkout; restore the row if that fails

  /// Removes [v] from the list and returns the index it occupied.
  ///
  /// If [v] was checked in from this kiosk, its host is freed straight away
  /// (the Check-in page shows them Available again) instead of waiting out the
  /// undo window; [undoCheckOut] or a failed commit puts the host back.
  int stageCheckOut(Visitor v) {
    ref.read(recentCheckInsProvider.notifier).update(
        v.copyWith(status: VisitorStatus.checkedOut, checkOutAt: DateTime.now()));
    final s = state.value;
    if (s == null) return 0;
    final i = s.items.indexWhere((x) => x.id == v.id);
    if (i < 0) return 0;
    state = AsyncData(s.copyWith(items: [...s.items]..removeAt(i)));
    return i;
  }

  void undoCheckOut(Visitor v, int index) {
    ref.read(recentCheckInsProvider.notifier).update(v); // host is busy again
    _put(v, index);
  }

  /// Throws on failure after restoring the row.
  Future<void> commitCheckOut(Visitor v, int index) async {
    try {
      final updated = await ref.read(checkOutVisitorProvider)(v.id);
      ref.read(recentCheckInsProvider.notifier).update(updated);
      // Under the "all" filter the row stays, now as checked out. Under a
      // status filter it no longer belongs, so it stays removed.
      if (ref.read(visitorFilterProvider) == null) _put(updated, index);
    } catch (_) {
      ref.read(recentCheckInsProvider.notifier).update(v); // still checked in
      _put(v, index);
      rethrow;
    }
  }

  void _put(Visitor v, int index) {
    final s = state.value;
    if (s == null) return;
    final items = [...s.items];
    final existing = items.indexWhere((x) => x.id == v.id);
    if (existing >= 0) {
      items[existing] = v; // a refresh already re-added it; don't duplicate
    } else {
      items.insert(index.clamp(0, items.length), v);
    }
    state = AsyncData(s.copyWith(items: items));
  }
}

final visitorsProvider =
    AsyncNotifierProvider<VisitorsController, VisitorsState>(VisitorsController.new);
