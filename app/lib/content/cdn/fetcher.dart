import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

class FetchResult {
  const FetchResult(this.status, this.body, {this.etag});
  final int status;
  final List<int> body;
  final String? etag;
}

/// Plain GETs. Requests carry nothing beyond what HTTP needs: no identifiers, no analytics.
abstract class Fetcher {
  Future<FetchResult> get(Uri url, {String? etag});
}

class HttpFetcher implements Fetcher {
  HttpFetcher({this.timeout = const Duration(seconds: 20)});
  final Duration timeout;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  @override
  Future<FetchResult> get(Uri url, {String? etag}) async {
    final request = await _client.getUrl(url).timeout(timeout);
    if (etag != null) request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
    final response = await request.close().timeout(timeout);
    final body = <int>[];
    await response.forEach(body.addAll).timeout(timeout);
    return FetchResult(response.statusCode, body, etag: response.headers.value(HttpHeaders.etagHeader));
  }
}

class HashMismatch implements Exception {
  HashMismatch(this.url);
  final Uri url;
  @override
  String toString() => 'sha256 mismatch for $url';
}

/// Downloads a content-addressed file and refuses it unless its sha256 matches.
Future<List<int>> fetchVerified(Fetcher fetcher, Uri url, String sha256Hex) async {
  final r = await fetcher.get(url);
  if (r.status != 200) throw HttpException('HTTP ${r.status}', uri: url);
  if (!hashMatches(r.body, sha256Hex)) throw HashMismatch(url);
  return r.body;
}

bool hashMatches(List<int> bytes, String sha256Hex) => sha256.convert(bytes).toString() == sha256Hex.toLowerCase();
