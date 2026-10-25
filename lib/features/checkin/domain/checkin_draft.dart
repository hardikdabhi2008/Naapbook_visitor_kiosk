import 'dart:typed_data';

/// The in-progress check-in form. Immutable; the controller persists it on
/// every change so it survives rotation, backgrounding and process death.
class CheckinDraft {
  const CheckinDraft({
    this.name = '',
    this.mobile = '',
    this.company = '',
    this.purposeId,
    this.hostId,
    this.hostName,
    this.hostDepartment,
    this.consent = false,
    this.photo,
  });

  final String name;
  final String mobile;
  final String company;
  final String? purposeId;
  final String? hostId;
  final String? hostName;
  final String? hostDepartment;
  final bool consent;
  final Uint8List? photo;

  static const _keep = Object();

  CheckinDraft copyWith({
    String? name,
    String? mobile,
    String? company,
    Object? purposeId = _keep,
    Object? hostId = _keep,
    Object? hostName = _keep,
    Object? hostDepartment = _keep,
    bool? consent,
    Object? photo = _keep,
  }) =>
      CheckinDraft(
        name: name ?? this.name,
        mobile: mobile ?? this.mobile,
        company: company ?? this.company,
        purposeId: identical(purposeId, _keep) ? this.purposeId : purposeId as String?,
        hostId: identical(hostId, _keep) ? this.hostId : hostId as String?,
        hostName: identical(hostName, _keep) ? this.hostName : hostName as String?,
        hostDepartment: identical(hostDepartment, _keep)
            ? this.hostDepartment
            : hostDepartment as String?,
        consent: consent ?? this.consent,
        photo: identical(photo, _keep) ? this.photo : photo as Uint8List?,
      );

  bool get isEmpty =>
      name.isEmpty &&
      mobile.isEmpty &&
      company.isEmpty &&
      purposeId == null &&
      hostId == null &&
      !consent &&
      photo == null;
}

abstract interface class DraftRepository {
  CheckinDraft load();
  Future<void> saveFields(CheckinDraft draft);
  Future<void> savePhoto(Uint8List? photo);
  Future<void> clear();
}
