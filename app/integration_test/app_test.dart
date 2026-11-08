// On-device end-to-end tests: the same flows as test/widget_test.dart, run on an emulator,
// simulator or phone. `flutter test integration_test -d <device>`.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/flows.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final f in flows.entries) {
    testWidgets(f.key, f.value);
  }
}
