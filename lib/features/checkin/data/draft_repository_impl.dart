import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/checkin_draft.dart';

/// Stores the draft in SharedPreferences (localStorage on web). The photo goes
/// under its own key so typing never rewrites the large base64 blob.
class DraftRepositoryImpl implements DraftRepository {
  DraftRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const _fields = 'draft.fields';
  static const _photo = 'draft.photo';

  @override
  CheckinDraft load() {
    try {
      final raw = _prefs.getString(_fields);
      final j = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
      final photo = _prefs.getString(_photo);
      return CheckinDraft(
        name: j['name'] as String? ?? '',
        mobile: j['mobile'] as String? ?? '',
        company: j['company'] as String? ?? '',
        purposeId: j['purposeId'] as String?,
        hostId: j['hostId'] as String?,
        hostName: j['hostName'] as String?,
        hostDepartment: j['hostDepartment'] as String?,
        consent: j['consent'] as bool? ?? false,
        photo: photo == null ? null : base64Decode(photo),
      );
    } catch (_) {
      return const CheckinDraft(); // corrupt draft: start clean
    }
  }

  @override
  Future<void> saveFields(CheckinDraft d) => _prefs.setString(
        _fields,
        jsonEncode({
          'name': d.name,
          'mobile': d.mobile,
          'company': d.company,
          'purposeId': d.purposeId,
          'hostId': d.hostId,
          'hostName': d.hostName,
          'hostDepartment': d.hostDepartment,
          'consent': d.consent,
        }),
      );

  @override
  Future<void> savePhoto(Uint8List? photo) => photo == null
      ? _prefs.remove(_photo)
      : _prefs.setString(_photo, base64Encode(photo));

  @override
  Future<void> clear() async {
    await _prefs.remove(_fields);
    await _prefs.remove(_photo);
  }
}
