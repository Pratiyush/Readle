import 'dart:math';

import 'package:flutter/material.dart';

import '../content/models.dart';
import '../logic/quiz.dart' show seedOf;
import 'app_scope.dart';
import 'reader_screen.dart';
import 'theme.dart';

const collections = {'all': 'All', 'fiction': 'Fiction', 'culture': 'Culture', 'facts': 'Facts'};

/// Same pick all day: a story of the chosen level, preferring unread ones.
StoryMeta? storyOfTheDay(List<StoryMeta> stories, String level, Map<String, String> read, String today) {
  final pool = stories.where((s) => level == 'all' || s.level == level).toList();
  if (pool.isEmpty) return null;
  final unread = pool.where((s) => !read.containsKey(s.id)).toList();
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
                        Text('Stories', style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    Chip(key: const Key('streak'), label: Text('🔥 ${state.streakDays}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 12),
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
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, children: children),
      );
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
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            if (image != null) Image(image: ResizeImage(image, width: 900), fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(keepGoing ? 'KEEP GOING — NEXT UP' : 'STORY OF THE DAY',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                Text(story.title,
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
    final image = AppScope.read(context).content.image(story.image);
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
                Text(story.title,
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
