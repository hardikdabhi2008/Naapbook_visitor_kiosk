import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/host.dart';

class HostModel extends Host {
  const HostModel({
    required super.id,
    required super.name,
    required super.designation,
    required super.department,
    required super.floor,
    required super.email,
    required super.available,
  });

  factory HostModel.fromJson(Map<String, dynamic> j) => HostModel(
        id: j['id'] as String,
        name: j['name'] as String,
        designation: (j['designation'] ?? '') as String,
        department: (j['department'] ?? '') as String,
        floor: (j['floor'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        available: j['available'] as bool? ?? true,
      );
}

class HostRepositoryImpl implements HostRepository {
  HostRepositoryImpl(this._dio);

  final Dio _dio;

  /// Fetches all 500 hosts once; searching is done on the client so typing
  /// never waits on the (slow, flaky) network.
  @override
  Future<List<Host>> fetchHosts() => guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/hosts');
        final items = (r.data!['items'] as List).cast<Map<String, dynamic>>();
        return items.map(HostModel.fromJson).toList(growable: false);
      });
}
