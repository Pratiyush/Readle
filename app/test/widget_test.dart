import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flows.dart';

void main() {
  for (final f in flows.entries) {
    testWidgets(f.key, (tester) async {
      tester.view.physicalSize = const Size(1125, 2436); // 375×812 at 3x
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await f.value(tester);
    });
  }
}
