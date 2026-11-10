// Host side of integration_test/perf_test.dart: one JSON file per scenario in build/perf/.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    for (final MapEntry(:key, :value) in (data ?? const <String, dynamic>{}).entries) {
      await writeResponseData(value as Map<String, dynamic>, testOutputFilename: key, destinationDirectory: 'build/perf');
    }
  },
);
