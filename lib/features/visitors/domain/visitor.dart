enum VisitorStatus {
  checkedIn('checked_in'),
  checkedOut('checked_out'),
  expected('expected');

  const VisitorStatus(this.wire);
  final String wire;

  static VisitorStatus parse(String s) => VisitorStatus.values
      .firstWhere((e) => e.wire == s, orElse: () => VisitorStatus.expected);
}

class Visitor {
  const Visitor({
    required this.id,
    required this.name,
    required this.mobile,
    required this.company,
    required this.purposeId,
    required this.hostId,
    required this.hostName,
    required this.status,
    required this.checkInAt,
    required this.checkOutAt,
    required this.expectedAt,
    required this.hasPhoto,
    required this.badgeCode,
    required this.consent,
  });

  final String id;
  final String name;
  final String mobile;
  final String? company;
  final String purposeId;
  final String hostId;
  final String hostName;
  final VisitorStatus status;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? expectedAt;
  final bool hasPhoto;
  final String badgeCode;
  final bool consent;

  bool get canCheckOut => status == VisitorStatus.checkedIn;

  Visitor copyWith({VisitorStatus? status, DateTime? checkOutAt}) => Visitor(
        id: id,
        name: name,
        mobile: mobile,
        company: company,
        purposeId: purposeId,
        hostId: hostId,
        hostName: hostName,
        status: status ?? this.status,
        checkInAt: checkInAt,
        checkOutAt: checkOutAt ?? this.checkOutAt,
        expectedAt: expectedAt,
        hasPhoto: hasPhoto,
        badgeCode: badgeCode,
        consent: consent,
      );
}

class VisitorPage {
  const VisitorPage(this.items, this.nextCursor);
  final List<Visitor> items;
  final String? nextCursor;
}

class Purpose {
  const Purpose(this.id, this.label);
  final String id;
  final String label;
}

class NewVisitor {
  const NewVisitor({
    required this.name,
    required this.mobile,
    required this.company,
    required this.purposeId,
    required this.hostId,
    required this.consent,
    this.photoDataUrl,
  });

  final String name;
  final String mobile;
  final String? company;
  final String purposeId;
  final String hostId;
  final bool consent;
  final String? photoDataUrl;
}

abstract interface class VisitorRepository {
  Future<VisitorPage> fetchVisitors({
    VisitorStatus? status,
    String? cursor,
    int limit,
  });

  Future<Visitor> checkIn(NewVisitor visitor);

  /// Idempotent from the caller's view: an `already_checked_out` 409 resolves
  /// to the current visitor instead of throwing.
  Future<Visitor> checkOut(String id);

  Future<List<Purpose>> fetchPurposes();

  String photoUrl(String id);
}
