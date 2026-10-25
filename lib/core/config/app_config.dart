import 'package:flutter/foundation.dart';

/// Build-time and default configuration.
///
/// Override the API with `--dart-define=API_BASE_URL=http://192.168.1.20:4000`
/// when running on a physical device.
class AppConfig {
  const AppConfig._();

  static const _apiOverride = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiOverride.isNotEmpty) return _apiOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000'; // Android emulator -> host machine
    }
    return 'http://localhost:4000';
  }

  static const adminPin = '1234';
  static const defaultIdleSeconds = 20;
  static const minIdleSeconds = 10;
  static const maxIdleSeconds = 120;
  static const defaultBrandColor = 0xFF1565C0;

  /// The API rejects request bodies over 3 MB; keep the photo well below it.
  static const maxPhotoDataUrlChars = 2800000;
  static const searchDebounce = Duration(milliseconds: 300);
  static const undoWindow = Duration(seconds: 5);
  static const visitorsPageSize = 50;
}
