import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/visitor.dart';

class VisitorModel extends Visitor {
  const VisitorModel({
    required super.id,
    required super.name,
    required super.mobile,
    required super.company,
    required super.purposeId,
    required super.hostId,
    required super.hostName,
    required super.status,
    required super.checkInAt,
    required super.checkOutAt,
    required super.expectedAt,
    required super.hasPhoto,
    required super.badgeCode,
    required super.consent,
  });

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  factory VisitorModel.fromJson(Map<String, dynamic> j) => VisitorModel(
        id: j['id'] as String,
        name: j['name'] as String,
        mobile: (j['mobile'] ?? '') as String,
        company: j['company'] as String?,
        purposeId: (j['purpose'] ?? '') as String,
        hostId: (j['hostId'] ?? '') as String,
        hostName: (j['hostName'] ?? '') as String,
        status: VisitorStatus.parse(j['status'] as String),
        checkInAt: _date(j['checkInAt']),
        checkOutAt: _date(j['checkOutAt']),
        expectedAt: _date(j['expectedAt']),
        hasPhoto: j['hasPhoto'] as bool? ?? false,
        badgeCode: (j['badgeCode'] ?? '') as String,
        consent: j['consent'] as bool? ?? false,
      );
}

class VisitorRepositoryImpl implements VisitorRepository {
  VisitorRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<VisitorPage> fetchVisitors({
    VisitorStatus? status,
    String? cursor,
    int limit = AppConfig.visitorsPageSize,
  }) =>
      guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/visitors',
            queryParameters: {
              'limit': limit,
              'status': ?status?.wire,
              'cursor': ?cursor,
            });
        final items = (r.data!['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(VisitorModel.fromJson)
            .toList(growable: false);
        return VisitorPage(items, r.data!['nextCursor'] as String?);
      });

  @override
  Future<Visitor> checkIn(NewVisitor v) => guard(() async {
        final r = await _dio.post<Map<String, dynamic>>('/visitors', data: {
          'name': v.name,
          'mobile': v.mobile,
          if (v.company != null && v.company!.isNotEmpty) 'company': v.company,
          'purpose': v.purposeId,
          'hostId': v.hostId,
          'consent': v.consent,
          if (v.photoDataUrl != null) 'photo': v.photoDataUrl,
        });
        return VisitorModel.fromJson(r.data!);
      });

  @override
  Future<Visitor> checkOut(String id) async {
    try {
      return await guard(() async {
        final r = await _dio.post<Map<String, dynamic>>('/visitors/$id/checkout');
        return VisitorModel.fromJson(r.data!);
      });
    } on ApiException catch (e) {
      final current = e.body?['visitor'];
      if (e.code == 'already_checked_out' && current is Map<String, dynamic>) {
        return VisitorModel.fromJson(current);
      }
      rethrow;
    }
  }

  @override
  Future<List<Purpose>> fetchPurposes() => guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/purposes');
        return (r.data!['items'] as List)
            .cast<Map<String, dynamic>>()
            .map((p) => Purpose(p['id'] as String, p['label'] as String))
            .toList(growable: false);
      });

  @override
  String photoUrl(String id) => '${_dio.options.baseUrl}/visitors/$id/photo';
}
