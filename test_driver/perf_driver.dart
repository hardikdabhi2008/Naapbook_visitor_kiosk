import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Turns the timeline recorded by integration_test/scroll_perf_test.dart into a
/// summary (average / worst frame build + raster times, missed-frame ratio) and
/// saves it, with the raw timeline, under evidence/perf/.
Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        final timeline = driver.Timeline.fromJson(
            data['visitors_scroll'] as Map<String, dynamic>);
        final summary = driver.TimelineSummary.summarize(timeline);
        await summary.writeTimelineToFile(
          'visitors_scroll',
          destinationDirectory: 'evidence/perf',
          pretty: true,
          includeSummary: true,
        );
      },
    );
