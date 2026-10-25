import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../error/api_exception.dart';

/// One shared [Dio]. There is deliberately no auto-retry interceptor: the
/// brief wants visible error + retry states, and a blind retry of a POST could
/// create a duplicate visitor (the API has no idempotency key).
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));
  ref.onDispose(dio.close);
  return dio;
});

/// Runs [call] and converts any transport error into an [ApiException].
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    throw ApiException.from(e);
  }
}
