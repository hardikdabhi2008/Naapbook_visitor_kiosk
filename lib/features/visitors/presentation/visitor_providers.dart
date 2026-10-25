import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final purposesProvider = FutureProvider<List<Purpose>>(
  (ref) => ref.watch(visitorRepositoryProvider).fetchPurposes(),
);

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
    return VisitorsState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Pull-to-refresh. On failure the current list is kept and the error is
  /// rethrown for the caller to show.
  Future<void> refresh() async {
    final filter = ref.read(visitorFilterProvider);
    final page = await ref
        .read(visitorRepositoryProvider)
        .fetchVisitors(status: filter);
    if (ref.read(visitorFilterProvider) != filter) return;
    state = AsyncData(
        VisitorsState(items: page.items, nextCursor: page.nextCursor));
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
  int stageCheckOut(Visitor v) {
    final s = state.value;
    if (s == null) return 0;
    final i = s.items.indexWhere((x) => x.id == v.id);
    if (i < 0) return 0;
    state = AsyncData(s.copyWith(items: [...s.items]..removeAt(i)));
    return i;
  }

  void undoCheckOut(Visitor v, int index) => _put(v, index);

  /// Throws on failure after restoring the row.
  Future<void> commitCheckOut(Visitor v, int index) async {
    try {
      final updated = await ref.read(checkOutVisitorProvider)(v.id);
      // Under the "all" filter the row stays, now as checked out. Under a
      // status filter it no longer belongs, so it stays removed.
      if (ref.read(visitorFilterProvider) == null) _put(updated, index);
    } catch (_) {
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
