import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config.dart';
import '../content/models.dart';
import '../l10n/app_localizations.dart';

/// What a finished-story card shows. Every string is already localized by the caller: the card
/// is painted outside the widget tree, where there are no Localizations.
class ShareCardData {
  const ShareCardData({
    required this.eyebrow,
    required this.title,
    required this.level,
    required this.streak,
    this.score,
    required this.footer,
    this.quote,
    this.picture,
  });

  final String eyebrow, title, level, streak, footer;

  /// The quiz score chip, only for a result worth showing ([shareScoreFrom] % or more).
  final String? score;

  /// The story's first German sentence, shown as a quote.
  final String? quote;
  final ui.Image? picture;
}

/// The lowest quiz score the card shows; below it the card leaves the score off (people share wins).
const shareScoreFrom = 80;

/// The card for [story] finished with [pct] % on the quiz and a [streak]-day streak.
ShareCardData finishedStoryCard(AppLocalizations l, Story story, {required int pct, required int streak, ui.Image? picture}) =>
    ShareCardData(
      eyebrow: l.shareCardEyebrow,
      title: story.meta.title,
      level: story.meta.level,
      streak: l.shareCardStreak(streak),
      score: pct >= shareScoreFrom ? l.shareCardScore(pct) : null,
      footer: l.shareCardFooter(appName),
      quote: story.sentences.firstOrNull?.de,
      picture: picture,
    );

/// The card's size in logical pixels; [renderShareCard] paints it at 3×: 1080 × 1350 (4:5, what
/// chat apps and Instagram show without cropping).
const shareCardSize = Size(360, 450);

const _teal = Color(0xFF0F766E);
const _gold = Color(0xFFF4D58D); // the book's second page in the app icon

class ShareCard extends StatelessWidget {
  const ShareCard(this.data, {super.key});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final dim = white.withValues(alpha: 0.78);
    Widget chip(String text, {Color fill = const Color(0x33FFFFFF), Color ink = white}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text,
        style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
    return Container(
      width: shareCardSize.width,
      height: shareCardSize.height,
      color: _teal,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 170,
              child: data.picture == null
                  ? const ColoredBox(
                      color: Color(0x22FFFFFF),
                      child: Center(child: Text('📖', style: TextStyle(fontSize: 56))),
                    )
                  : RawImage(image: data.picture, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            data.eyebrow.toUpperCase(),
            style: TextStyle(color: dim, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(data.level, fill: _gold, ink: _teal),
              chip(data.streak),
              if (data.score != null) chip(data.score!),
            ],
          ),
          const SizedBox(height: 16),
          if (data.quote != null)
            Expanded(
              child: Text(
                '„${data.quote}“',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: white, fontSize: 17, fontStyle: FontStyle.italic, height: 1.3),
              ),
            )
          else
            const Spacer(),
          Text(
            data.footer,
            style: TextStyle(color: dim, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Loads [provider] into a [ui.Image] for the card, or null when it fails.
Future<ui.Image?> loadPicture(ImageProvider? provider) {
  if (provider == null) return Future.value();
  final done = Completer<ui.Image?>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      done.complete(info.image);
    },
    onError: (_, _) {
      stream.removeListener(listener);
      done.complete(null);
    },
  );
  stream.addListener(listener);
  return done.future;
}

/// Paints [card] outside the app's widget tree and returns it as a PNG.
Future<Uint8List> renderShareCard(Widget card, ui.FlutterView view, {double pixelRatio = 3}) async {
  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(shareCardSize),
      physicalConstraints: BoxConstraints.tight(shareCardSize),
      devicePixelRatio: 1,
    ),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final build = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: const MediaQueryData(size: shareCardSize),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 14, color: Colors.white),
          child: card,
        ),
      ),
    ),
  ).attachToRenderTree(build);
  build
    ..buildScope(root)
    ..finalizeTree();
  pipeline
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
