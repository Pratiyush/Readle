// iOS privacy manifests. Apple rejects an upload (ITMS-91053) when native code calls a
// required-reason API that no bundled PrivacyInfo.xcprivacy declares. Plugins compile into the
// Runner binary, so a reason a plugin's own manifest leaves out must be in Readle's (BUG-41).
//
// Binary SDKs (Google Mobile Ads, UMP, Flutter) ship their own manifests inside their frameworks;
// those are checked in the archive's privacy report, not here (docs/production-gate.md).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Apple's required-reason API categories and the names that mark them in Swift / Objective-C.
final _categories = {
  'FileTimestamp': RegExp(
    r'creationDate|modificationDate|contentModificationDateKey|NSFileCreationDate|NSFileModificationDate|'
    r'\bgetattrlist|\bfgetattrlist|\bstat\(|\bfstat\(|\bfstatat\(|\blstat\(',
  ),
  'SystemBootTime': RegExp(r'systemUptime|mach_absolute_time'),
  'DiskSpace': RegExp(
    r'volumeAvailableCapacity|volumeTotalCapacityKey|systemFreeSize|NSFileSystemFreeSize|NSFileSystemSize|'
    r'\bstatfs\(|\bstatvfs\(|\bfstatfs\(|\bfstatvfs\(',
  ),
  'ActiveKeyboards': RegExp(r'activeInputModes'),
  'UserDefaults': RegExp(r'UserDefaults'),
};

Set<String> _declared(String manifest) => {for (final m in RegExp(r'NSPrivacyAccessedAPICategory(\w+)').allMatches(manifest)) m.group(1)!};

void main() {
  final runner = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();

  test("Readle's own manifest: no tracking or collection by app code, in the Runner target", () {
    expect(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(runner), isTrue);
    expect(RegExp(r'<key>NSPrivacyCollectedDataTypes</key>\s*<array/>').hasMatch(runner), isTrue);
    expect(File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(), contains('PrivacyInfo.xcprivacy in Resources'));
  });

  test('every required-reason API an iOS plugin calls is declared by its manifest or by Readle', () {
    final config = File('.dart_tool/package_config.json');
    final packages = (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages'] as List;
    final undeclared = <String>[];
    var plugins = 0;
    for (final p in packages.cast<Map<String, dynamic>>()) {
      if (p['name'] == 'readle') continue;
      final root = config.absolute.uri.resolve(p['rootUri'] as String).toFilePath();
      final native = [
        for (final d in ['ios', 'darwin']) Directory('$root/$d'),
      ].where((d) => d.existsSync());
      if (native.isEmpty) continue;
      plugins++;
      final files = [for (final d in native) ...d.listSync(recursive: true).whereType<File>()];
      final declared = {
        ..._declared(runner),
        for (final f in files.where((f) => f.path.endsWith('PrivacyInfo.xcprivacy'))) ..._declared(f.readAsStringSync()),
      };
      for (final f in files.where((f) => RegExp(r'\.(swift|m|mm|h|c)$').hasMatch(f.path))) {
        final source = f.readAsStringSync();
        for (final MapEntry(key: category, value: marker) in _categories.entries) {
          if (!declared.contains(category) && marker.hasMatch(source)) {
            undeclared.add('${p['name']}: $category (${f.uri.pathSegments.last})');
          }
        }
      }
    }
    expect(plugins, greaterThan(5), reason: 'the plugins were found');
    expect(undeclared.toSet(), isEmpty, reason: 'declare the reason in ios/Runner/PrivacyInfo.xcprivacy');
  });
}
