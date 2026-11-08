// Smoke test against the live CDN (network). Skipped by default; run it before a release with
//   flutter test --run-skipped --tags live test/cdn_live_test.dart
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readle/content/cdn/fetcher.dart';
import 'package:readle/content/cdn/manifest.dart';
import 'package:readle/content/linker.dart';

void main() {
  test('live manifest, feed and A1 stories verify, and Readle links their words', () async {
    final fetcher = HttpFetcher();
    final base = Uri.parse(cdnBase);
    final r = await fetcher.get(base.resolve('manifest.json'));
    expect(r.status, 200);
    expect(r.etag, isNotNull);
    final m = Manifest.fromJson(jsonDecode(utf8.decode(r.body)) as Map<String, dynamic>);
    expect(m.minClient, lessThanOrEqualTo(contentClientVersion), reason: 'this build can still read the CDN');
    expect(m.contentVersion, greaterThanOrEqualTo(bundledContentVersion));

    final feed = FeedStory.listFromJson(
        jsonDecode(utf8.decode(await fetchVerified(fetcher, base.resolve(m.feedStories!.url), m.feedStories!.sha256)))
            as Map<String, dynamic>);
    expect(feed, isNotEmpty);

    final a1 = m.levels['A1']!.stories!;
    final pack = jsonDecode(utf8.decode(await fetchVerified(fetcher, base.resolve(a1.url), a1.sha256))) as Map<String, dynamic>;
    final linker = Linker.fromJson(jsonDecode(File('assets/linker/linker.json').readAsStringSync()) as Map<String, dynamic>);
    var words = 0, linked = 0;
    for (final s in (pack['stories'] as List).cast<Map<String, dynamic>>()) {
      for (final sentence in (s['sentences'] as List).cast<Map<String, dynamic>>()) {
        for (final t in linker.tokenise(sentence['de'] as String).whereType<List>()) {
          words++;
          if (t.length > 1) linked++;
        }
      }
    }
    expect(linked / words, greaterThan(0.95), reason: '$linked of $words words linked');
  });
}
