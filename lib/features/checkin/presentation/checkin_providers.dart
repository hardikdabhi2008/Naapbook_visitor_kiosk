  import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/storage/prefs_provider.dart';
import '../../hosts/domain/host.dart';
import '../../visitors/domain/visitor.dart';
import '../../visitors/presentation/visitor_providers.dart';
import '../data/draft_repository_impl.dart';
import '../domain/checkin_draft.dart';

final draftRepositoryProvider = Provider<DraftRepository>(
  (ref) => DraftRepositoryImpl(ref.watch(sharedPrefsProvider)),
);

/// Form state. Loaded synchronously from prefs, written through on each edit.
class CheckinController extends Notifier<CheckinDraft> {
  /// True only while the form still holds the draft found at startup;
  /// cleared by [clear] (which also runs after a successful submit).
  bool restored = false;

  @override
  CheckinDraft build() {
    final draft = ref.watch(draftRepositoryProvider).load();
    restored = !draft.isEmpty;
    return draft;
  }

  DraftRepository get _repo => ref.read(draftRepositoryProvider);

  void _set(CheckinDraft next) {
    state = next;
    _repo.saveFields(next);
  }

  void setName(String v) => _set(state.copyWith(name: v));
  void setMobile(String v) => _set(state.copyWith(mobile: v));
  void setCompany(String v) => _set(state.copyWith(company: v));
  void setPurpose(String? v) => _set(state.copyWith(purposeId: v));
  void setConsent(bool v) => _set(state.copyWith(consent: v));

  void setHost(Host h) => _set(state.copyWith(
        hostId: h.id,
        hostName: h.name,
        hostDepartment: h.department,
      ));

  void setPhoto(Uint8List? bytes) {
    state = state.copyWith(photo: bytes);
    _repo.savePhoto(bytes);
  }

  Future<void> clear() async {
    restored = false;
    state = const CheckinDraft();
    await _repo.clear();
  }
}

final checkinProvider =
    NotifierProvider<CheckinController, CheckinDraft>(CheckinController.new);

class SubmitState {
  const SubmitState({this.busy = false, this.error});
  final bool busy;
  final ApiException? error;
}

class SubmitController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  void dismissError() => state = const SubmitState();

  /// Returns the created visitor, or null on failure (see [state].error).
  Future<Visitor?> submit() async {
    if (state.busy) return null;
    state = const SubmitState(busy: true);
    try {
      final draft = ref.read(checkinProvider);
      final visitor = await ref.read(submitCheckInProvider)(draft);
      ref.read(lastCheckInProvider.notifier).set(visitor, draft.photo);
      await ref.read(checkinProvider.notifier).clear();
      state = const SubmitState();
      // Today's list is now stale. Pin the new visitor on top of it first: the
      // server may sort a check-in made "now" far down the day's list.
      ref.read(recentCheckInsProvider.notifier).add(visitor);
      ref.invalidate(visitorsProvider);
      return visitor;
    } catch (e) {
      state = SubmitState(error: ApiException.from(e));
      return null;
    }
  }
}

final submitProvider =
    NotifierProvider<SubmitController, SubmitState>(SubmitController.new);

/// The most recent successful check-in, shown on the badge screen.
class LastCheckIn {
  const LastCheckIn(this.visitor, this.photo);
  final Visitor visitor;
  final Uint8List? photo;
}

class LastCheckInController extends Notifier<LastCheckIn?> {
  @override
  LastCheckIn? build() => null;

  void set(Visitor v, Uint8List? photo) => state = LastCheckIn(v, photo);
  void clear() => state = null;
}

final lastCheckInProvider =
    NotifierProvider<LastCheckInController, LastCheckIn?>(LastCheckInController.new);
