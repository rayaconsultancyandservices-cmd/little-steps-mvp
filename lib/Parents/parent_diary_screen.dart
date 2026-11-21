import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../widgets/parent_widgets.dart';
import 'parent_home_screen.dart' show ParentColors;

/// Colours + icon used for one diary subject (Rhyme, Letter, Number ...).
class _Subject {
  const _Subject(this.icon, this.bg, this.fg);

  final IconData icon;
  final Color bg;
  final Color fg;
}

/// P3 · Class Diary  (published by the teacher)
class ParentDiaryScreen extends StatefulWidget {
  const ParentDiaryScreen({super.key, this.onBack});

  /// Back arrow action. By default it goes back to Home
  /// (the shell handles the system back for the tabs).
  final VoidCallback? onBack;

  @override
  State<ParentDiaryScreen> createState() => _ParentDiaryScreenState();
}

class _ParentDiaryScreenState extends State<ParentDiaryScreen> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  int _selected = 0;

  /// "Practice at home" items the parent has marked as done.
  final Set<String> _done = {};

  /// "Send tomorrow" items the parent has packed.
  final Set<String> _packed = {};

  // ---------------------------------------------------------------
  // SUBJECT LOOK
  // ---------------------------------------------------------------
  static _Subject _subject(String label) {
    switch (label.toLowerCase()) {
      case 'rhyme':
        return const _Subject(
            Icons.music_note_rounded, Color(0xFFFFE9EE), Color(0xFFE0587A));
      case 'letter':
        return const _Subject(
            Icons.abc_rounded, Color(0xFFE6F3FD), Color(0xFF2B8FDB));
      case 'number':
        return const _Subject(
            Icons.pin_outlined, Color(0xFFDDF2EC), Color(0xFF2F8877));
      case 'colour':
      case 'color':
        return const _Subject(
            Icons.palette_rounded, Color(0xFFFFF0D9), Color(0xFFD9822B));
      case 'activity':
        return const _Subject(
            Icons.brush_rounded, Color(0xFFEFE8FF), Color(0xFF7B5CD6));
      case 'story':
        return const _Subject(
            Icons.auto_stories_rounded, Color(0xFFFFE7E5), Color(0xFFD9564F));
      case 'game':
        return const _Subject(Icons.sports_esports_rounded, Color(0xFFE3F1FF),
            Color(0xFF3F7FC4));
      case 'shape':
        return const _Subject(
            Icons.category_rounded, Color(0xFFDDF2EC), Color(0xFF2F8877));
      case 'craft':
        return const _Subject(
            Icons.content_cut_rounded, Color(0xFFFFF0D9), Color(0xFFD9822B));
      default:
        return const _Subject(
            Icons.edit_note_rounded, Color(0xFFE6F3FD), Color(0xFF2B8FDB));
    }
  }

  static String _moodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'excited':
        return '🤩';
      case 'calm':
        return '😌';
      case 'sleepy':
        return '😴';
      case 'energetic':
      case 'active':
        return '⚡';
      case 'curious':
        return '🧐';
      default:
        return '🙂';
    }
  }

  String _key(DiaryPost p, String what) =>
      '${p.date.year}-${p.date.month}-${p.date.day}:$what';

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final posts = s.diaryPosts;
        final index = posts.isEmpty ? 0 : _selected.clamp(0, posts.length - 1);
        final post = posts.isEmpty ? null : posts[index];
        final todayPublished = s.diaryFor(DateTime.now()) != null;

        return Column(
          children: [
            _header(s, post),
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
                    if (posts.isNotEmpty) ...[
                      _dateStrip(posts, index),
                      const SizedBox(height: 12),
                    ],
                    if (!todayPublished) ...[
                      _notPublishedBanner(),
                      const SizedBox(height: 12),
                    ],
                    if (post == null)
                      _empty()
                    else ...[
                      _heroCard(s, post),
                      const SizedBox(height: 12),
                      _lessonsCard(post),
                      if (post.homeNote.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _practiceCard(post),
                      ],
                      if (post.bring.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _bringCard(post),
                      ],
                      const SizedBox(height: 12),
                      _dayNavigator(posts, index),
                    ],
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
  // HEADER (back arrow + title + copy)
  // ---------------------------------------------------------------
  Widget _roundBtn(IconData icon, VoidCallback? onTap, {String? tooltip}) {
    final enabled = onTap != null;
    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : .45,
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
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  Widget _header(AppState s, DiaryPost? post) {
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
                  'Class Diary',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.className} · what ${s.child.firstName} learned',
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
            Icons.copy_rounded,
            post == null ? null : () => _copyDiary(s, post),
            tooltip: 'Copy diary',
          ),
        ],
      ),
    );
  }

  Future<void> _copyDiary(AppState s, DiaryPost post) async {
    final b = StringBuffer()
      ..writeln('Class Diary · ${s.className}')
      ..writeln(AppState.dateLabel(post.date))
      ..writeln();
    for (final i in post.items) {
      b.writeln('${i.label}: ${i.text}');
    }
    if (post.mood != null) b.writeln('Class mood: ${post.mood}');
    if (post.homeNote.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('Practice at home: ${post.homeNote}');
    }
    if (post.bring.isNotEmpty) {
      b.writeln('Send tomorrow: ${post.bring.join(', ')}');
    }
    await Clipboard.setData(ClipboardData(text: b.toString().trim()));
    if (mounted) showSnack(context, 'Diary copied.');
  }

  // ---------------------------------------------------------------
  // DATE STRIP
  // ---------------------------------------------------------------
  Widget _dateStrip(List<DiaryPost> posts, int index) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = posts[i].date;
          final on = i == index;
          final isToday = AppState.sameDay(d, DateTime.now());
          return GestureDetector(
            onTap: () => setState(() => _selected = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 52,
              decoration: BoxDecoration(
                color: on ? ParentColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: on ? ParentColors.primary : ParentColors.border),
                boxShadow: on
                    ? const [
                  BoxShadow(
                    color: Color(0x442B8FDB),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdays[d.weekday - 1].toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                      color: on
                          ? Colors.white.withValues(alpha: .85)
                          : ParentColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: on ? Colors.white : ParentColors.dark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday
                          ? (on ? Colors.white : ParentColors.primary)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _notPublishedBanner() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6DD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2D58A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded, size: 17, color: Color(0xFFB7791F)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Today’s diary is not published yet. Showing earlier days.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A5210),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // HERO CARD (date, teacher, quick stats)
  // ---------------------------------------------------------------
  Widget _heroCard(AppState s, DiaryPost post) {
    final isToday = AppState.sameDay(post.date, DateTime.now());
    final teacher = s.teacherName;

    Widget stat(String top, String bottom) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                top,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                bottom,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .85),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ParentColors.primary, ParentColors.primaryLight],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x442B8FDB),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -34,
              child: _circle(110, Colors.white.withValues(alpha: .12)),
            ),
            Positioned(
              left: -28,
              bottom: -44,
              child: _circle(96, Colors.white.withValues(alpha: .09)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .6),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          initialsOf(teacher.replaceFirst('Ms. ', '')),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: ParentColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isToday
                                  ? 'Taught today'
                                  : 'Taught on ${AppState.dateLabel(post.date)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$teacher · class teacher',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: .9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      stat('${post.items.length}', 'Activities'),
                      const SizedBox(width: 8),
                      stat(
                        post.mood == null
                            ? '—'
                            : '${_moodEmoji(post.mood!)} ${post.mood!}',
                        'Class mood',
                      ),
                      const SizedBox(width: 8),
                      stat(AppState.timeLabel(post.publishedAt), 'Published'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  // ---------------------------------------------------------------
  // LESSONS (timeline)
  // ---------------------------------------------------------------
  BoxDecoration _cardDecoration({Color color = Colors.white, Color? border}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border ?? ParentColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142B8FDB),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      );

  Widget _cardTitle(IconData icon, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: ParentColors.tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: ParentColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: ParentColors.dark,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _lessonsCard(DiaryPost post) {
    final items = post.items;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.menu_book_rounded,
            'What we learned',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: ParentColors.tint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${items.length} topic${items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: ParentColors.primary,
                ),
              ),
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No activities added for this day.',
                style: TextStyle(fontSize: 11.5, color: ParentColors.muted),
              ),
            ),
          for (var i = 0; i < items.length; i++)
            _lessonRow(items[i], last: i == items.length - 1),
          if (post.mood != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ParentColors.tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(_moodEmoji(post.mood!),
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Class mood',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: ParentColors.muted,
                          ),
                        ),
                        Text(
                          post.mood!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: ParentColors.dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lessonRow(DiaryLine line, {required bool last}) {
    final sub = _subject(line.label);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: sub.bg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(sub.icon, size: 17, color: sub.fg),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: ParentColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 10 : 14, top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                      color: sub.fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line.text,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
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
    );
  }

  // ---------------------------------------------------------------
  // PRACTICE AT HOME (checkable)
  // ---------------------------------------------------------------
  Widget _practiceCard(DiaryPost post) {
    final k = _key(post, 'practice');
    final done = _done.contains(k);
    return GestureDetector(
      onTap: () => setState(() {
        if (!_done.add(k)) _done.remove(k);
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(
          color: done ? const Color(0xFFE8F7EF) : const Color(0xFFFFF6DD),
          border: done ? const Color(0xFFB9E4CB) : const Color(0xFFF2D58A),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFF22A06B).withValues(alpha: .15)
                    : ParentColors.gold.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                done ? Icons.check_circle_rounded : Icons.home_rounded,
                size: 18,
                color: done ? const Color(0xFF22A06B) : const Color(0xFFB7791F),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? 'Practice done 🎉' : 'Practice at home',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: done
                          ? const Color(0xFF1B7A52)
                          : const Color(0xFF9A6410),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.homeNote,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: ParentColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    done ? 'Tap to undo' : 'Tap when you have practised',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: ParentColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              done
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 22,
              color: done ? const Color(0xFF22A06B) : const Color(0xFFB7791F),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // SEND TOMORROW (packing checklist)
  // ---------------------------------------------------------------
  Widget _bringCard(DiaryPost post) {
    final packedCount =
        post.bring.where((b) => _packed.contains(_key(post, 'bring:$b'))).length;
    final all = packedCount == post.bring.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.backpack_rounded,
            'Send tomorrow',
            trailing: Text(
              all ? 'All packed ✓' : '$packedCount / ${post.bring.length} packed',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: all ? const Color(0xFF22A06B) : ParentColors.muted,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in post.bring) _bringChip(post, b),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap an item once it is in the school bag.',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: ParentColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bringChip(DiaryPost post, String item) {
    final k = _key(post, 'bring:$item');
    final on = _packed.contains(k);
    return GestureDetector(
      onTap: () => setState(() {
        if (!_packed.add(k)) _packed.remove(k);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFE8F7EF) : const Color(0xFFFFEFEC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on ? const Color(0xFFB9E4CB) : const Color(0xFFF6CFC7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 14,
              color: on ? const Color(0xFF22A06B) : ParentColors.danger,
            ),
            const SizedBox(width: 6),
            Text(
              item,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                decoration: on ? TextDecoration.lineThrough : null,
                color: on ? const Color(0xFF1B7A52) : ParentColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // PREVIOUS / NEXT DAY
  // ---------------------------------------------------------------
  Widget _dayNavigator(List<DiaryPost> posts, int index) {
    final hasOlder = index < posts.length - 1;
    final hasNewer = index > 0;

    Widget btn(String label, IconData icon, bool enabled, VoidCallback onTap,
        {bool iconRight = false}) {
      return Expanded(
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : .4,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ParentColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!iconRight) ...[
                    Icon(icon, size: 16, color: ParentColors.primary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ParentColors.dark,
                    ),
                  ),
                  if (iconRight) ...[
                    const SizedBox(width: 4),
                    Icon(icon, size: 16, color: ParentColors.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn(
          'Earlier day',
          Icons.chevron_left_rounded,
          hasOlder,
              () => setState(() => _selected = index + 1),
        ),
        const SizedBox(width: 10),
        btn(
          'Next day',
          Icons.chevron_right_rounded,
          hasNewer,
              () => setState(() => _selected = index - 1),
          iconRight: true,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // EMPTY
  // ---------------------------------------------------------------
  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: ParentColors.tintStrong,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_book_outlined,
                size: 30, color: ParentColors.primary),
          ),
          const SizedBox(height: 12),
          const Text(
            'No diary entries yet.\nTeacher will publish the class diary here.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
}