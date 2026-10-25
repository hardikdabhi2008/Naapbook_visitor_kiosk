import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves screenshots taken with binding.takeScreenshot() into evidence/auto/.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('evidence/auto/$name.png');
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);
        return true;
      },
    );
