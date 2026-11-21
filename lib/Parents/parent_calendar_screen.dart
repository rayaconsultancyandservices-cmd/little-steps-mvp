import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/parent_widgets.dart';
import 'parent_home_screen.dart' show ParentColors;

/// P8 · Holidays & Events (Calendar)
/// Teacher ने circular मध्ये event date दिली की ती इथे आपोआप दिसते.
///
/// Features:
///  - Back arrow (same as the other screens) + "Today" jump button
///  - "Next event" banner with countdown
///  - Month calendar: swipe or arrows to change month, event dots, today ring
///  - Tap a day to see its events (tap again to clear)
///  - Category filter chips (All / Holiday / Meeting / Event / Celebration)
///  - Event list for the selected day or the whole month
///  - Event detail sheet with copy
class ParentCalendarScreen extends StatefulWidget {
  const ParentCalendarScreen({super.key, this.onBack});

  /// Back arrow action. By default it closes this screen.
  final VoidCallback? onBack;

  @override
  State<ParentCalendarScreen> createState() => _ParentCalendarScreenState();
}

class _ParentCalendarScreenState extends State<ParentCalendarScreen> {
  static const _categories = ['Holiday', 'Meeting', 'Event', 'Celebration'];

  late DateTime _month;
  DateTime? _selected;
  String? _filter; // null = All

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  // ---------- helpers ----------
  void _shift(int by) => setState(() {
    _month = DateTime(_month.year, _month.month + by);
    _selected = null;
  });

  void _goToday() {
    final n = DateTime.now();
    setState(() {
      _month = DateTime(n.year, n.month);
      _selected = DateTime(n.year, n.month, n.day);
    });
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<SchoolEvent> _all(AppState s) => s.events
      .where((e) => _filter == null || e.category == _filter)
      .toList();

  List<SchoolEvent> _on(List<SchoolEvent> all, DateTime d) =>
      all.where((e) => _same(e.date, d)).toList();

  int _daysFromToday(DateTime d) =>
      DateTime(d.year, d.month, d.day).difference(_today).inDays;

  String _countdown(DateTime d) {
    final n = _daysFromToday(d);
    if (n == 0) return 'Today';
    if (n == 1) return 'Tomorrow';
    if (n == -1) return 'Yesterday';
    if (n < 0) return '${-n} days ago';
    return 'In $n days';
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentColors.pageBg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: AppState.instance,
          builder: (context, _) {
            final s = AppState.instance;
            final all = _all(s);

            final next = all.where((e) => _daysFromToday(e.date) >= 0).toList();
            final monthEvents = all
                .where((e) =>
            e.date.year == _month.year && e.date.month == _month.month)
                .toList();

            final listEvents =
            _selected != null ? _on(all, _selected!) : monthEvents;
            final listTitle = _selected != null
                ? AppState.dateLabel(_selected!)
                : 'Events in ${AppState.monthName(_month.month)}';

            return Column(
              children: [
                _header(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (next.isNotEmpty) ...[
                        _nextBanner(next.first),
                        const SizedBox(height: 14),
                      ],
                      _calendarCard(all),
                      const SizedBox(height: 12),
                      _filterChips(),
                      const SizedBox(height: 16),
                      _listHeader(listTitle, listEvents.length),
                      if (listEvents.isEmpty)
                        _empty(_selected != null
                            ? 'No events on this day'
                            : 'No events this month')
                      else
                        for (final e in listEvents) _eventTile(context, e),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------- header (back arrow + title + today) ----------
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          _roundBtn(
            Icons.arrow_back_ios_new_rounded,
            widget.onBack ?? () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Holidays & events',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.muted,
                  ),
                ),
              ],
            ),
          ),
          _roundBtn(Icons.today_rounded, _goToday, tooltip: 'Go to today'),
        ],
      ),
    );
  }

  // ---------- next event banner ----------
  Widget _nextBanner(SchoolEvent e) {
    final fg = kCategoryFg[e.category] ?? ParentColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ParentColors.primary, ParentColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332B8FDB),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('${e.date.day}',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: fg)),
                Text(AppState.monthShort(e.date.month),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: fg)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NEXT EVENT',
                    style: TextStyle(
                        color: Color(0xFFEAF5FD),
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_countdown(e.date),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ---------- calendar ----------
  Widget _calendarCard(List<SchoolEvent> all) {
    final first = DateTime(_month.year, _month.month, 1);
    final leading = first.weekday - 1; // Monday पासून सुरुवात
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((leading + daysInMonth) / 7).ceil();

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -250) _shift(1);
        if (v > 250) _shift(-1);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: _cardDeco(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  _roundBtn(Icons.chevron_left_rounded, () => _shift(-1),
                      tooltip: 'Previous month'),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${AppState.monthName(_month.month)} ${_month.year}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: ParentColors.dark,
                        ),
                      ),
                    ),
                  ),
                  _roundBtn(Icons.chevron_right_rounded, () => _shift(1),
                      tooltip: 'Next month'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(d,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: d == 'S'
                                  ? const Color(0xFFD9564F)
                                  : ParentColors.muted)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (int r = 0; r < rows; r++)
              Row(
                children: [
                  for (int c = 0; c < 7; c++)
                    Expanded(
                        child: _cell(all, r * 7 + c - leading + 1, daysInMonth)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(List<SchoolEvent> all, int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 44);

    final date = DateTime(_month.year, _month.month, day);
    final events = _on(all, date);
    final isToday = _same(date, _today);
    final isSelected = _selected != null && _same(date, _selected!);
    final cat = events.isEmpty ? null : events.first.category;

    Color bg = Colors.transparent;
    Color fg = ParentColors.dark;
    if (cat != null) {
      bg = kCategoryBg[cat] ?? AppColors.blueLight;
      fg = kCategoryFg[cat] ?? ParentColors.primary;
    }
    if (isToday) {
      bg = ParentColors.primary;
      fg = Colors.white;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = isSelected ? null : date),
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: ParentColors.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.1,
                    fontWeight: (isToday || cat != null)
                        ? FontWeight.w900
                        : FontWeight.w600,
                    color: fg)),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in events.take(3))
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.white
                            : (kCategoryFg[e.category] ?? fg),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- filter chips ----------
  Widget _filterChips() {
    Widget chip(String label, String? value) {
      final selected = _filter == value;
      final bg = value == null
          ? Colors.white
          : (kCategoryBg[value] ?? AppColors.blueLight);
      final fg = value == null
          ? ParentColors.dark
          : (kCategoryFg[value] ?? ParentColors.primary);

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? (value == null ? ParentColors.primary : fg) : bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? (value == null ? ParentColors.primary : fg)
                    : ParentColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null) ...[
                  Icon(kCategoryIcon[value] ?? Icons.event_rounded,
                      size: 13, color: selected ? Colors.white : fg),
                  const SizedBox(width: 4),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : fg)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('All', null),
          for (final c in _categories) chip(c, c),
        ],
      ),
    );
  }

  // ---------- list ----------
  Widget _listHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark)),
          ),
          if (_selected != null)
            GestureDetector(
              onTap: () => setState(() => _selected = null),
              child: const Text('Show month',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: ParentColors.primary)),
            )
          else
            Text('$count',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ParentColors.muted)),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: ParentColors.tintStrong,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 26, color: ParentColors.primary),
          ),
          const SizedBox(height: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ParentColors.dark)),
        ],
      ),
    );
  }

  Widget _eventTile(BuildContext context, SchoolEvent e) {
    final bg = kCategoryBg[e.category] ?? AppColors.blueLight;
    final fg = kCategoryFg[e.category] ?? ParentColors.primary;
    final past = _daysFromToday(e.date) < 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: past ? 0.6 : 1,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openEvent(context, e),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F14375A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      children: [
                        Text('${e.date.day}',
                            style: TextStyle(
                                fontSize: 17,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: fg)),
                        Text(AppState.monthShort(e.date.month),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: fg)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: ParentColors.dark)),
                        if (e.note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(e.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ParentColors.muted)),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            StatusChip(e.category, bg: bg, fg: fg),
                            const SizedBox(width: 8),
                            const Icon(Icons.schedule_rounded,
                                size: 12, color: ParentColors.muted),
                            const SizedBox(width: 3),
                            Text(_countdown(e.date),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ParentColors.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: ParentColors.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- event detail sheet ----------
  void _openEvent(BuildContext context, SchoolEvent e) {
    final bg = kCategoryBg[e.category] ?? AppColors.blueLight;
    final fg = kCategoryFg[e.category] ?? ParentColors.primary;
    final icon = kCategoryIcon[e.category] ?? Icons.event_rounded;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 24, color: fg),
                  ),
                  const SizedBox(width: 12),
                  StatusChip(e.category, bg: bg, fg: fg),
                  const Spacer(),
                  Text(_countdown(e.date),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.muted)),
                ],
              ),
              const SizedBox(height: 14),
              Text(e.title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                      color: ParentColors.dark)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.event_rounded,
                      size: 16, color: ParentColors.primary),
                  const SizedBox(width: 6),
                  Text(AppState.dateLabel(e.date),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ParentColors.dark)),
                ],
              ),
              if (e.note.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(e.note,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: AppColors.text)),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(
                          text: '${e.title}\n'
                              '${AppState.dateLabel(e.date)}\n'
                              '${e.note}',
                        ));
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          showSnack(context, 'Event copied');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ParentColors.primary,
                        side: const BorderSide(color: ParentColors.border),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle:
                        const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParentColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle:
                        const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0F14375A),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  );
}