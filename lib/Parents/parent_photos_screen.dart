import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../state/app_state.dart';
import '../widgets/parent_widgets.dart';
import 'parent_home_screen.dart' show ParentColors;

// =====================================================================
// DATA HELPERS
// =====================================================================
class _Item {
  const _Item(this.key, this.photo);

  /// Unique id of a photo (used for favourites + Hero animation).
  final String key;
  final SharedPhoto photo;
}

class _Group {
  _Group(this.day);

  final DateTime day;
  final List<_Item> items = [];
  String caption = '';
  DateTime? sentAt;
}

class _Entry {
  const _Entry(this.item, this.group);

  final _Item item;
  final _Group group;
}

const List<IconData> _kSceneIcons = [
  Icons.palette_rounded,
  Icons.toys_rounded,
  Icons.park_rounded,
  Icons.music_note_rounded,
];

/// P2 · Photos  (My child / Class photos)
class ParentPhotosScreen extends StatefulWidget {
  const ParentPhotosScreen({super.key, this.onBack});

  /// Back arrow action. By default it goes back to Home
  /// (the shell handles the system back for the tabs).
  final VoidCallback? onBack;

  @override
  State<ParentPhotosScreen> createState() => _ParentPhotosScreenState();
}

class _ParentPhotosScreenState extends State<ParentPhotosScreen> {
  int _tab = 0; // 0 = My child, 1 = Class photos
  int _range = 0; // 0 All, 1 Today, 2 This week, 3 Favourites
  bool _mosaic = true; // big first photo + grid  /  plain grid

  final ValueNotifier<Set<String>> _favs = ValueNotifier<Set<String>>({});

  String get _favKey => 'parent_photo_favs_${AppState.instance.child.id}';

  @override
  void initState() {
    super.initState();
    ParentPrefs.load(_favKey).then((v) {
      if (mounted && v.isNotEmpty) _favs.value = {..._favs.value, ...v};
    });
    _favs.addListener(() => ParentPrefs.save(_favKey, _favs.value));
  }

  @override
  void dispose() {
    _favs.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------
  List<_Group> _groups(AppState s, int tab) {
    final groups = <_Group>[];
    for (final b in s.photoBatches) {
      // Firestore query आधीच फक्त या मुलाचे + whole-class photos देते (audience).
      // त्यामुळे नावाने पुन्हा गाळायची गरज नाही — नाहीतर tag नसलेले / वेगळ्या
      // spelling चे photos हरवायचे.
      final list = tab == 0
          ? b.photos
          .where((p) => !b.wholeClass || s.child.matches(p.tags))
          .toList()
          : (b.wholeClass ? b.photos : <SharedPhoto>[]);
      if (list.isEmpty) continue;

      _Group? g;
      for (final x in groups) {
        if (AppState.sameDay(x.day, b.sentAt)) g = x;
      }
      if (g == null) {
        g = _Group(b.sentAt);
        g.caption = b.caption;
        g.sentAt = b.sentAt;
        groups.add(g);
      }
      for (var pi = 0; pi < list.length; pi++) {
        final p = list[pi];
        // Stable key: नवीन photos आले तरी जुन्या favourites चा key बदलत नाही.
        final key = '$tab:${b.sentAt.millisecondsSinceEpoch}:$pi';
        g.items.add(_Item(key, p));
      }
    }
    return groups;
  }

  int _count(List<_Group> groups) =>
      groups.fold<int>(0, (sum, g) => sum + g.items.length);

  List<_Group> _filtered(List<_Group> groups) {
    if (_range == 0) return groups;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final out = <_Group>[];
    for (final g in groups) {
      final day = DateTime(g.day.year, g.day.month, g.day.day);
      var items = g.items;
      if (_range == 1 && day != today) continue;
      if (_range == 2 && today.difference(day).inDays > 6) continue;
      if (_range == 3) {
        items = items.where((i) => _favs.value.contains(i.key)).toList();
      }
      if (items.isEmpty) continue;
      final copy = _Group(g.day)
        ..caption = g.caption
        ..sentAt = g.sentAt;
      copy.items.addAll(items);
      out.add(copy);
    }
    return out;
  }

  void _toggleFav(String key) {
    final next = Set<String>.from(_favs.value);
    if (!next.add(key)) next.remove(key);
    _favs.value = next;
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppState.instance, _favs]),
      builder: (context, _) {
        final s = AppState.instance;
        final childGroups = _groups(s, 0);
        final classGroups = _groups(s, 1);
        final current = _tab == 0 ? childGroups : classGroups;
        final shown = _filtered(current);
        final total = _count(current);
        final favCount = current.fold<int>(
          0,
              (n, g) =>
          n + g.items.where((i) => _favs.value.contains(i.key)).length,
        );

        return Column(
          children: [
            _header(s),
            Expanded(
              child: RefreshIndicator(
                color: ParentColors.primary,
                onRefresh: () async {
                  await Future<void>.delayed(const Duration(milliseconds: 600));
                  if (mounted) setState(() {});
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  children: [
                    _tabs(_count(childGroups), _count(classGroups)),
                    const SizedBox(height: 10),
                    _summary(total, current.length, favCount),
                    const SizedBox(height: 10),
                    _filters(favCount),
                    const SizedBox(height: 12),
                    if (shown.isEmpty) _empty(s),
                    for (final g in shown) ...[
                      _groupHeader(g),
                      const SizedBox(height: 8),
                      _groupBody(g, shown),
                      const SizedBox(height: 16),
                    ],
                    if (_tab == 1) _privacyNote(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // HEADER (back arrow + title + layout toggle)
  // ---------------------------------------------------------------
  Widget _roundBtn(IconData icon, VoidCallback onTap, {String? tooltip}) {
    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: ParentColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x142B8FDB),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: ParentColors.dark),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  Widget _header(AppState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          _roundBtn(
            Icons.arrow_back_ios_new_rounded,
            widget.onBack ?? () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.className} · moments of ${s.child.firstName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.muted,
                  ),
                ),
              ],
            ),
          ),
          _roundBtn(
            _mosaic ? Icons.grid_view_rounded : Icons.dashboard_rounded,
                () => setState(() => _mosaic = !_mosaic),
            tooltip: _mosaic ? 'Grid view' : 'Highlight view',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // TABS  (My child / Class photos) with counts
  // ---------------------------------------------------------------
  Widget _tabs(int childCount, int classCount) {
    Widget seg(String label, IconData icon, int count, int v) {
      final on = _tab == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = v),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? ParentColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: on
                  ? const [
                BoxShadow(
                  color: Color(0x332B8FDB),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 15, color: on ? Colors.white : ParentColors.muted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : ParentColors.muted,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: on
                        ? Colors.white.withValues(alpha: .25)
                        : ParentColors.tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : ParentColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParentColors.border),
      ),
      child: Row(
        children: [
          seg('My child', Icons.child_care_rounded, childCount, 0),
          seg('Class photos', Icons.groups_rounded, classCount, 1),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // SUMMARY STRIP
  // ---------------------------------------------------------------
  Widget _summary(int photos, int days, int favs) {
    Widget cell(IconData icon, String value, String label) {
      return Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: ParentColors.tint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 14, color: ParentColors.primary),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget divider() => Container(
      width: 1,
      height: 26,
      color: ParentColors.border,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParentColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142B8FDB),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          cell(Icons.photo_library_rounded, '$photos', 'Photos'),
          divider(),
          cell(Icons.calendar_month_rounded, '$days', 'Days'),
          divider(),
          cell(Icons.favorite_rounded, '$favs', 'Favourites'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // FILTER CHIPS
  // ---------------------------------------------------------------
  Widget _filters(int favCount) {
    Widget chip(String label, int v, {IconData? icon}) {
      final on = _range == v;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _range = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: on ? ParentColors.dark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: on ? ParentColors.dark : ParentColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 12,
                      color: on ? Colors.white : ParentColors.danger),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : ParentColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', 0),
          chip('Today', 1),
          chip('This week', 2),
          chip('Favourites', 3, icon: Icons.favorite_rounded),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // DATE GROUP
  // ---------------------------------------------------------------
  Widget _groupHeader(_Group g) {
    final isToday = AppState.sameDay(g.day, DateTime.now());
    final title = isToday ? 'Today' : AppState.dateLabel(g.day);
    final when = AppState.relativeDay(g.sentAt ?? g.day);
    final caption = g.caption.trim().isEmpty ? 'Class photos' : g.caption;

    return Row(
      children: [
        Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isToday ? ParentColors.primary : ParentColors.tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '${g.day.day}',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: isToday ? Colors.white : ParentColors.primary,
                ),
              ),
              Text(
                AppState.monthShort(g.day.month).toUpperCase(),
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                  color: isToday
                      ? Colors.white.withValues(alpha: .85)
                      : ParentColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: ParentColors.dark,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$caption · $when',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: ParentColors.muted,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ParentColors.border),
          ),
          child: Text(
            '${g.items.length} photo${g.items.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ParentColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupBody(_Group g, List<_Group> all) {
    final entries = <_Entry>[
      for (final x in all)
        for (final it in x.items) _Entry(it, x),
    ];
    final isToday = AppState.sameDay(g.day, DateTime.now());

    Widget tile(_Item it, double aspect) {
      final index = entries.indexWhere((e) => e.item.key == it.key);
      return AspectRatio(
        aspectRatio: aspect,
        child: _PhotoCard(
          item: it,
          isNew: isToday,
          fav: _favs.value.contains(it.key),
          onFav: () => _toggleFav(it.key),
          onTap: () => _openViewer(entries, index < 0 ? 0 : index),
        ),
      );
    }

    final items = g.items;
    final useHero = _mosaic && items.length >= 3;
    final rest = useHero ? items.sublist(1) : items;

    return Column(
      children: [
        if (useHero) ...[
          tile(items.first, 1.7),
          const SizedBox(height: 8),
        ],
        LayoutBuilder(
          builder: (context, c) {
            const gap = 8.0;
            final w = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final it in rest)
                  SizedBox(width: w, child: tile(it, 1.15)),
              ],
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // EMPTY + PRIVACY NOTE
  // ---------------------------------------------------------------
  Widget _empty(AppState s) {
    String text;
    IconData icon = Icons.photo_library_outlined;
    if (_range == 3) {
      text = 'No favourites yet.\nTap the heart on a photo to save it here.';
      icon = Icons.favorite_border_rounded;
    } else if (_range == 1) {
      text = 'No photos shared today yet.';
    } else if (_range == 2) {
      text = 'No photos shared this week.';
    } else {
      text = _tab == 0
          ? 'No photos of ${s.child.firstName} yet.\nTeacher will share moments here.'
          : 'No class photos yet.';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: ParentColors.tintStrong,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: ParentColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: ParentColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ParentColors.tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded,
              size: 17, color: ParentColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Class photos are shared only with parents of this class.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: ParentColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // FULL-SCREEN VIEWER
  // ---------------------------------------------------------------
  void _openViewer(List<_Entry> entries, int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => _PhotoViewer(
          entries: entries,
          initial: index,
          favs: _favs,
          onToggleFav: _toggleFav,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// =====================================================================
// PHOTO ART (placeholder picture until real photos are connected)
// =====================================================================
class _PhotoArt extends StatelessWidget {
  const _PhotoArt({required this.colorIndex, this.iconSize = 34, this.url});

  final int colorIndex;
  final double iconSize;

  /// Teacher ने खरा photo upload केला असेल तर त्याचा Firebase Storage link.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url;
    // बदल: Teacher चा फोटो 'data:image/jpeg;base64,...' स्वरूपात येतो (Spark plan).
    if (u != null && u.startsWith('data:')) {
      final bytes = _decode(u);
      if (bytes == null) return _placeholder();
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (u != null && u.isNotEmpty) {
      return Image.network(
        u,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) => progress == null
            ? child
            : _placeholder(),
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  // वारंवार decode होऊ नये म्हणून cache.
  static final Map<String, Uint8List> _cache = {};

  static Uint8List? _decode(String dataUri) {
    final hit = _cache[dataUri];
    if (hit != null) return hit;
    try {
      final b = UriData.parse(dataUri).contentAsBytes();
      if (_cache.length > 60) _cache.clear();
      _cache[dataUri] = b;
      return b;
    } catch (_) {
      return null;
    }
  }

  Widget _placeholder() {
    final i = colorIndex % kPhotoColors.length;
    final base = kPhotoColors[i];
    final deep = kPhotoIconColors[i];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, .35)!,
            Color.lerp(base, deep, .55)!,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // soft "bokeh" circles so it feels like a real photo
          Positioned(
            right: -22,
            top: -22,
            child: _blob(90, Colors.white.withValues(alpha: .28)),
          ),
          Positioned(
            left: -26,
            bottom: -30,
            child: _blob(100, Colors.white.withValues(alpha: .18)),
          ),
          Positioned(
            left: 18,
            top: 16,
            child: _blob(14, Colors.white.withValues(alpha: .35)),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _kSceneIcons[colorIndex % _kSceneIcons.length],
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
          // vignette
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// =====================================================================
// PHOTO CARD (grid tile)
// =====================================================================
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.item,
    required this.isNew,
    required this.fav,
    required this.onTap,
    required this.onFav,
  });

  final _Item item;
  final bool isNew;
  final bool fav;
  final VoidCallback onTap;
  final VoidCallback onFav;

  @override
  Widget build(BuildContext context) {
    final tags = item.photo.tags;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F2B8FDB),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'photo-${item.key}',
                child: _PhotoArt(
                    colorIndex: item.photo.colorIndex, url: item.photo.url),
              ),
              if (isNew)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: ParentColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 7,
                top: 7,
                child: GestureDetector(
                  onTap: onFav,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .92),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      fav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 14,
                      color: fav ? ParentColors.danger : ParentColors.muted,
                    ),
                  ),
                ),
              ),
              if (tags.isNotEmpty)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .38),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_pin_rounded,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  tags.join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// FULL-SCREEN PHOTO VIEWER (swipe, zoom, favourite, copy caption)
// =====================================================================
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.entries,
    required this.initial,
    required this.favs,
    required this.onToggleFav,
  });

  final List<_Entry> entries;
  final int initial;
  final ValueNotifier<Set<String>> favs;
  final void Function(String key) onToggleFav;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _page;
  late int _index;
  bool _saving = false;

  /// नवीन: Photo फोनच्या gallery मध्ये save करतो ("Little Steps" album).
  Future<void> _save(_Entry e) async {
    if (_saving) return;
    final url = e.item.photo.url;
    if (url == null || url.isEmpty) {
      showSnack(context, 'This photo cannot be saved.');
      return;
    }
    setState(() => _saving = true);
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final bytes = await consolidateHttpClientResponseBytes(res);
      await Gal.putImageBytes(bytes, album: 'Little Steps');
      if (mounted) showSnack(context, 'Saved to gallery.');
    } catch (_) {
      // Gal.putImageBytes स्वतः gallery ची परवानगी मागतो; नाकारली तर किंवा
      // network अडचण आली तर इथे येतो.
      if (mounted) {
        showSnack(context,
            'Could not save. Allow photo access and check your internet.');
      }
    } finally {
      client.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initial;
    _page = PageController(initialPage: widget.initial);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entries[_index];
    final g = entry.group;
    final caption = g.caption.trim().isEmpty ? 'Class photo' : g.caption;
    final tags = entry.item.photo.tags;

    return Scaffold(
      backgroundColor: const Color(0xFF111A22),
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.entries.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final e = widget.entries[i];
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Hero(
                      tag: 'photo-${e.item.key}',
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _PhotoArt(
                            url: e.item.photo.url,
                            colorIndex: e.item.photo.colorIndex,
                            iconSize: 56,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ---- top bar ----
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _glassBtn(Icons.close_rounded, () => Navigator.pop(context)),
                  const Spacer(),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.entries.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // नवीन: Save to gallery
                  _saving
                      ? Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : _glassBtn(
                    Icons.download_rounded,
                        () => _save(entry),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: widget.favs,
                    builder: (context, favs, _) {
                      final on = favs.contains(entry.item.key);
                      return _glassBtn(
                        on
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                            () => widget.onToggleFav(entry.item.key),
                        color: on ? const Color(0xFFFF7A66) : Colors.white,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ---- bottom info ----
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  18, 30, 18, 18 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .75),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Shared by ${AppState.instance.teacherName} · '
                        '${AppState.relativeDay(g.sentAt ?? g.day)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: .8),
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_pin_rounded,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  t,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(
                        text: '$caption · ${AppState.dateLabel(g.day)} · '
                            '${AppState.instance.className}',
                      ));
                      if (context.mounted) {
                        showSnack(context, 'Photo details copied.');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 14, color: ParentColors.dark),
                          SizedBox(width: 6),
                          Text(
                            'Copy details',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ParentColors.dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap,
      {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }

}