import 'dart:math';

import 'package:flutter/material.dart';

import '../content/cdn/content_client.dart';
import '../content/layered_repository.dart';
import '../content/models.dart';
import '../logic/quiz.dart' show seedOf;
import 'app_scope.dart';
import 'reader_screen.dart';
import 'theme.dart';
import 'whole_words_text.dart';

const collections = {'all': 'All', 'fiction': 'Fiction', 'culture': 'Culture', 'facts': 'Facts'};

/// Same pick all day, preferring unread stories. "All levels" goes in sequence, A1 → B2: the pick
/// comes from the lowest level that still has unread stories, so a beginner isn't handed B2 on day one.
StoryMeta? storyOfTheDay(List<StoryMeta> stories, String level, Map<String, String> read, String today) {
  final pool = stories.where((s) => level == 'all' || s.level == level).toList();
  if (pool.isEmpty) return null;
  var unread = pool.where((s) => !read.containsKey(s.id)).toList();
  if (level == 'all') {
    final next = levels.where((l) => unread.any((s) => s.level == l)).firstOrNull;
    if (next != null) unread = unread.where((s) => s.level == next).toList();
  }
  final from = unread.isEmpty ? pool : unread;
  return from[Random(seedOf(today)).nextInt(from.length)];
}

void openStory(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(storyId: id)));

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<StoryMeta>> _library;
  String _collection = 'all';
  String _query = '';
  bool _unreadOnly = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _library = AppScope.read(context).content.library();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final state = scope.state;
    final palette = Palette.of(context);
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<StoryMeta>>(
        future: _library,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Couldn't load stories.", style: TextStyle(color: palette.muted)));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final stories = snap.data!;
          final level = state.settings.level;
          final q = _query.trim().toLowerCase();
          final visible = stories
              .where((s) =>
                  (level == 'all' || s.level == level) &&
                  (_collection == 'all' || s.collection == _collection) &&
                  (!_unreadOnly || !state.read.containsKey(s.id)) &&
                  (q.isEmpty || [s.title, s.teaser, s.teaserEn].any((t) => t.toLowerCase().contains(q))))
              .toList();
          final daily = storyOfTheDay(stories, level, state.read, state.today);
          final resumeId = state.continueStory;
          final resume = resumeId == null ? null : stories.where((s) => s.id == resumeId).firstOrNull;
          // Ad placement map: an inline banner after the 6th story, then every 8, so a phone screen
          // never holds two (none when ads are off).
          final rows = <Widget>[];
          for (var i = 0; i < visible.length; i++) {
            rows.add(_StoryCard(story: visible[i], read: state.read.containsKey(visible[i].id)));
            if (i == 5 || (i > 5 && (i - 5) % 8 == 0)) {
              final ad = scope.ads.listBanner();
              if (ad != null) rows.add(KeyedSubtree(key: ValueKey('ad-$i'), child: ad));
            }
          }

          return CustomScrollView(
            key: const PageStorageKey('library'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList.list(children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('GUTEN TAG!', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 12)),
                        // One word: shrink to fit beside the streak chip rather than break mid-word.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Stories',
                              key: const Key('library-heading'),
                              style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ),
                    Chip(key: const Key('streak'), label: Text('🔥 ${state.streakDays}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 12),
                  if (scope.updates != null)
                    _UpdateBanner(onInstalled: () => setState(() {
                      _library = scope.content.library();
                    })),
                  if (resume != null) ...[_ContinueCard(story: resume), const SizedBox(height: 12)],
                  if (daily != null) _DailyCard(story: daily, keepGoing: state.readToday > 0),
                  const SizedBox(height: 12),
                  _Chips(children: [
                    _chip('All levels', level == 'all', () => state.updateSettings(state.settings.copyWith(level: 'all'))),
                    for (final l in levels) _chip(l, level == l, () => state.updateSettings(state.settings.copyWith(level: l))),
                  ]),
                  _Chips(children: [
                    for (final c in collections.entries) _chip(c.value, _collection == c.key, () => setState(() => _collection = c.key)),
                    _chip('Unread', _unreadOnly, () => setState(() => _unreadOnly = !_unreadOnly)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('search'),
                    decoration: InputDecoration(
                      hintText: 'Search stories…',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: palette.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: palette.line)),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No stories match these filters.', textAlign: TextAlign.center, style: TextStyle(color: palette.muted)),
                    ),
                ]),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => rows[i],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(label: Text(label), selected: on, showCheckmark: false, onSelected: (_) => onTap()),
      );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.children});
  final List<Widget> children;

  @override
  // Grows with the text size, so labels are never cut off (48 at 100 %).
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.textScalerOf(context).scale(20) + 28,
        child: ListView(scrollDirection: Axis.horizontal, children: children),
      );
}

/// The story the learner opened last and hasn't finished: one tap back to where they were.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.story});
  final StoryMeta story;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final image = AppScope.read(context).content.image(story.thumb ?? story.image);
    return Card(
      key: const Key('continue-card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openStory(context, story.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: image == null ? ColoredBox(color: palette.surface2) : Image(image: ResizeImage(image, width: 168), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CONTINUE READING', style: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                WholeWordsText(story.title, style: const TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
            Icon(Icons.play_circle_fill_rounded, color: scheme.primary, size: 36),
          ]),
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.story, required this.keepGoing});
  final StoryMeta story;
  final bool keepGoing;

  @override
  Widget build(BuildContext context) {
    final image = AppScope.read(context).content.image(story.image);
    return Card(
      key: const Key('daily'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openStory(context, story.id),
        // At least 16:9; taller when large text needs the room, so the title is never clipped.
        child: LayoutBuilder(
          builder: (context, c) => Stack(children: [
            if (image != null) Positioned.fill(child: Image(image: ResizeImage(image, width: 900), fit: BoxFit.cover)),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                ),
              ),
            ),
            Container(
              constraints: BoxConstraints(minHeight: c.maxWidth * 9 / 16),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(keepGoing ? 'KEEP GOING — NEXT UP' : 'STORY OF THE DAY',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                WholeWordsText(story.title,
                    key: const Key('daily-title'),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: serif, fontFamilyFallback: serifFallback, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  LevelBadge(story.level),
                  Text('${story.minutes} min · ${collections[story.collection] ?? story.collection}', style: const TextStyle(color: Colors.white)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.read});
  final StoryMeta story;
  final bool read;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final image = AppScope.read(context).content.image(story.thumb ?? story.image);
    return Card(
      key: Key('story-${story.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openStory(context, story.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 92,
                height: 92,
                // Decode at thumbnail size: the source pictures are 1536 px wide.
                child: image == null
                    ? ColoredBox(color: palette.surface2, child: const Center(child: Text('📖', style: TextStyle(fontSize: 32))))
                    : Image(image: ResizeImage(image, width: 276), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                WholeWordsText(story.title,
                    style: const TextStyle(fontFamily: serif, fontFamilyFallback: serifFallback, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(story.teaserEn, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted)),
                const SizedBox(height: 6),
                // Wraps rather than overflows on narrow phones and large text sizes.
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  LevelBadge(story.level),
                  Text('${story.minutes} min · ${collections[story.collection] ?? story.collection}',
                      style: TextStyle(color: palette.muted, fontSize: 13)),
                  if (read) Text('✓ Read', style: TextStyle(color: palette.good, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "New stories" from the content CDN: offered, never downloaded without a tap. Hidden when there
/// is nothing new; asks for an app update when the CDN needs a newer client.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.onInstalled});
  final VoidCallback onInstalled;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final updates = scope.updates!;
    if (updates.kind == UpdateKind.none) return const SizedBox.shrink();
    final tooOld = updates.kind == UpdateKind.appTooOld;
    final n = updates.newStories;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: const Key('content-update'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                tooOld ? 'Update the app to get new stories.' : n == 1 ? '📚 1 new story to read' : '📚 $n new stories to read',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (!tooOld)
                FilledButton(
                  key: const Key('content-update-button'),
                  onPressed: updates.busy
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          if (await updates.update()) {
                            final content = scope.content;
                            if (content is LayeredContentRepository) await content.reload();
                            onInstalled();
                          } else {
                            messenger?.showSnackBar(const SnackBar(content: Text("Couldn't download the new stories. Try again later.")));
                          }
                        },
                  child: updates.busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Download'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
