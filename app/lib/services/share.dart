import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

/// The system share sheet. Readle shares an image card and a line of text; nothing is uploaded
/// by the app itself — the learner picks where it goes.
abstract interface class Sharer {
  /// Opens the share sheet with [png] and [text]. [origin] anchors the sheet on iPad.
  Future<void> share({required Uint8List png, required String text, required String fileName, Rect? origin});
}

class SystemSharer implements Sharer {
  @override
  Future<void> share({required Uint8List png, required String text, required String fileName, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        text: text,
        sharePositionOrigin: origin,
      ),
    );
  }
}

/// Records what would be shared. Used by tests.
class RecordingSharer implements Sharer {
  final shared = <({Uint8List png, String text, String fileName})>[];

  @override
  Future<void> share({required Uint8List png, required String text, required String fileName, Rect? origin}) async {
    shared.add((png: png, text: text, fileName: fileName));
  }
}
