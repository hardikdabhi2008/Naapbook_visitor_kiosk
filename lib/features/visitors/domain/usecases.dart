import 'dart:typed_data';

import '../../../core/config/app_config.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/utils/image_mime.dart';
import '../../checkin/domain/checkin_draft.dart';
import 'visitor.dart';

class SubmitCheckIn {
  const SubmitCheckIn(this._repo);
  final VisitorRepository _repo;

  Future<Visitor> call(CheckinDraft d) {
    final Uint8List? photo = d.photo;
    final dataUrl = photo == null ? null : ImageMime.toDataUrl(photo);
    if (dataUrl != null && dataUrl.length > AppConfig.maxPhotoDataUrlChars) {
      // Fail locally rather than uploading a body the API will 413.
      throw const ApiException(FailureKind.tooLarge);
    }
    return _repo.checkIn(NewVisitor(
      name: d.name.trim(),
      mobile: d.mobile,
      company: d.company.trim().isEmpty ? null : d.company.trim(),
      purposeId: d.purposeId!,
      hostId: d.hostId!,
      consent: d.consent,
      photoDataUrl: dataUrl,
    ));
  }
}

class CheckOutVisitor {
  const CheckOutVisitor(this._repo);
  final VisitorRepository _repo;

  Future<Visitor> call(String id) => _repo.checkOut(id);
}
