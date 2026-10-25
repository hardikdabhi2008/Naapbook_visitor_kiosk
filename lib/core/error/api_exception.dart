import 'package:dio/dio.dart';

enum FailureKind {
  network,
  timeout,
  server,
  validation,
  notFound,
  conflict,
  tooLarge,
  unknown,
}

/// The single error type the domain and presentation layers see.
class ApiException implements Exception {
  const ApiException(
    this.kind, {
    this.statusCode,
    this.code,
    this.fields = const {},
    this.body,
  });

  final FailureKind kind;
  final int? statusCode;

  /// The API's `error` string, e.g. `already_checked_out`.
  final String? code;

  /// Per-field messages from a 422 response.
  final Map<String, String> fields;
  final Map<String, dynamic>? body;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ApiException(FailureKind.timeout);
        case DioExceptionType.connectionError:
          return const ApiException(FailureKind.network);
        case DioExceptionType.badResponse:
          return _fromResponse(error.response);
        default:
          return const ApiException(FailureKind.unknown);
      }
    }
    return const ApiException(FailureKind.unknown);
  }

  static ApiException _fromResponse(Response<dynamic>? r) {
    final status = r?.statusCode ?? 0;
    final data = r?.data;
    final body = data is Map<String, dynamic> ? data : null;
    final code = body?['error'] as String?;
    final rawFields = body?['fields'];
    final fields = rawFields is Map
        ? rawFields.map((k, v) => MapEntry('$k', '$v'))
        : const <String, String>{};
    final kind = switch (status) {
      422 => FailureKind.validation,
      404 => FailureKind.notFound,
      409 => FailureKind.conflict,
      413 => FailureKind.tooLarge,
      >= 500 => FailureKind.server,
      _ => FailureKind.unknown,
    };
    return ApiException(kind,
        statusCode: status, code: code, fields: fields, body: body);
  }

  @override
  String toString() => 'ApiException($kind, status: $statusCode, code: $code)';
}
