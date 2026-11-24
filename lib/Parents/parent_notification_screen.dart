import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';

import 'parent_home_screen.dart' show ParentColors;

/// One notification row shown on the Parent notification screen.
class ParentNotifItem {
  const ParentNotifItem(this.icon, this.text, this.tab, {String? key})
      : key = key ?? text;

  final IconData icon;
  final String text;

  /// Read / clear ची नोंद ठेवण्यासाठी unique key (तारीख / id सहित).
  final String key;

  /// Bottom tab to open when tapped:
  /// 0 Home, 1 Photos, 2 Diary, 3 Circulars, 4 Fees, 5 Messages, 6 Leave
  final int tab;
}

/// Parent app · Notifications screen (opened from the bell icon on Home).
///
/// Features:
///  - Back arrow (same as the other screens) + "mark all read" button
///  - Unread count in the subtitle
///  - Filter chips: All, Unread and one per type (Circulars, Fees, ...)
///  - Grouped list: New / Earlier
///  - Coloured icon per type, unread dot, type chip
///  - Swipe a notification away (with Undo) or "Clear all"
///  - Tap to open the related screen
class ParentNotificationScreen extends StatefulWidget {
  const ParentNotificationScreen({
    super.key,
    required this.items,
    required this.onOpenTab,
  });

  final List<ParentNotifItem> items;

  /// Called with the tab index after this screen is closed.
  final ValueChanged<int> onOpenTab;

  @override
  State<ParentNotificationScreen> createState() =>
      _ParentNotificationScreenState();
}

/// Read / cleared notifications फोन मध्ये save (मुलानुसार) — नाहीतर screen
/// पुन्हा उघडल्यावर सगळं परत "unread" दिसायचं.
class ParentNotifStore {
  static String _read(String c) => 'parent_notif_read_$c';
  static String _gone(String c) => 'parent_notif_gone_$c';

  static Future<(Set<String>, Set<String>)> load(String childId) async {
    try {
      final p = await SharedPreferences.getInstance();
      return (
      (p.getStringList(_read(childId)) ?? const <String>[]).toSet(),
      (p.getStringList(_gone(childId)) ?? const <String>[]).toSet(),
      );
    } catch (_) {
      return (<String>{}, <String>{});
    }
  }

  static Future<void> save(
      String childId, Set<String> read, Set<String> gone) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_read(childId), read.toList());
      await p.setStringList(_gone(childId), gone.toList());
    } catch (_) {}
  }

  /// Badge साठी: read किंवा cleared झालेले सगळे.
  static Future<Set<String>> hidden(String childId) async {
    final r = await load(childId);
    return {...r.$1, ...r.$2};
  }
}

/// Style for each notification type (based on the tab it opens).
class _Kind {
  const _Kind(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;
}

const Map<int, _Kind> _kinds = {
  1: _Kind('Photos', Color(0xFFD9564F), Color(0xFFFFE7E5)),
  2: _Kind('Class diary', Color(0xFF2F8877), Color(0xFFDDF2EC)),
  3: _Kind('Circulars', Color(0xFF3F7FC4), Color(0xFFE3F1FF)),
  4: _Kind('Fees', Color(0xFFD9822B), Color(0xFFFFF0D9)),
  5: _Kind('Messages', Color(0xFF7B5CD6), Color(0xFFEFE8FF)),
  // नवीन: रजेच्या अर्जाचा निर्णय (Approved / Declined)
  6: _Kind('Leave', Color(0xFF22A06B), Color(0xFFE3F6EC)),
};

const _Kind _defaultKind =
_Kind('Update', ParentColors.primary, ParentColors.tintStrong);

class _ParentNotificationScreenState extends State<ParentNotificationScreen> {
  final Set<int> _read = {};
  final Set<int> _dismissed = {};

  /// null = All, -1 = Unread, otherwise a tab number.
  int? _filter;

  String get _childId => AppState.instance.child.id;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = await ParentNotifStore.load(_childId);
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < widget.items.length; i++) {
        if (saved.$1.contains(widget.items[i].key)) _read.add(i);
        if (saved.$2.contains(widget.items[i].key)) _dismissed.add(i);
      }
    });
  }

  void _persist() {
    ParentNotifStore.save(
      _childId,
      {for (final i in _read) if (i < widget.items.length) widget.items[i].key},
      {
        for (final i in _dismissed)
          if (i < widget.items.length) widget.items[i].key
      },
    );
  }

  // ---------- helpers ----------
  _Kind _kind(int tab) => _kinds[tab] ?? _defaultKind;

  Iterable<int> get _alive sync* {
    for (var i = 0; i < widget.items.length; i++) {
      if (!_dismissed.contains(i)) yield i;
    }
  }

  int get _unreadCount => _alive.where((i) => !_read.contains(i)).length;

  List<int> get _visible => _alive.where((i) {
    if (_filter == null) return true;
    if (_filter == -1) return !_read.contains(i);
    return widget.items[i].tab == _filter;
  }).toList();

  void _markAllRead() {
    setState(() => _read.addAll(_alive));
    _persist();
  }

  void _snackUndo(String text, VoidCallback undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Undo', onPressed: undo),
        ),
      );
  }

  void _dismiss(int index) {
    setState(() => _dismissed.add(index));
    _persist();
    _snackUndo('Notification removed', () {
      if (mounted) setState(() => _dismissed.remove(index));
      _persist();
    });
  }

  void _clearAll() {
    final removed = _visible;
    if (removed.isEmpty) return;
    setState(() => _dismissed.addAll(removed));
    _persist();
    _snackUndo('Cleared ${removed.length} notifications', () {
      if (mounted) setState(() => _dismissed.removeAll(removed));
      _persist();
    });
  }

  void _open(int index) {
    final n = widget.items[index];
    setState(() => _read.add(index));
    _persist();
    Navigator.pop(context);
    widget.onOpenTab(n.tab);
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final fresh = visible.where((i) => !_read.contains(i)).toList();
    final earlier = visible.where((i) => _read.contains(i)).toList();
    final hasAny = _alive.isNotEmpty;

    return Scaffold(
      backgroundColor: ParentColors.pageBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [ParentColors.skyTop, ParentColors.pageBg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              if (hasAny) _filterChips(),
              if (hasAny) const SizedBox(height: 10),
              Expanded(
                child: !hasAny
                    ? _empty(
                  Icons.notifications_none_rounded,
                  'You are all caught up',
                  'New updates will show up here.',
                )
                    : visible.isEmpty
                    ? _empty(
                  Icons.filter_list_off_rounded,
                  'Nothing here',
                  'No notifications match this filter.',
                )
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    if (fresh.isNotEmpty) ...[
                      _groupLabel('New', fresh.length),
                      for (final i in fresh) _tile(context, i, true),
                    ],
                    if (earlier.isNotEmpty) ...[
                      _groupLabel('Earlier', earlier.length),
                      for (final i in earlier) _tile(context, i, false),
                    ],
                    const SizedBox(height: 4),
                    const Center(
                      child: Text('Swipe left to remove a notification',
                          style: TextStyle(
                              fontSize: 10.5,
                              color: ParentColors.muted,
                              fontWeight: FontWeight.w600)),
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

  // ---------- header (back arrow + title + actions) ----------
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

  Widget _header(BuildContext context) {
    final unread = _unreadCount;
    final hasAny = _alive.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          _roundBtn(
            Icons.arrow_back_ios_new_rounded,
                () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !hasAny
                      ? 'No notifications'
                      : unread == 0
                      ? 'All read'
                      : '$unread new',
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
            Icons.done_all_rounded,
            unread == 0 ? null : _markAllRead,
            tooltip: 'Mark all read',
          ),
          const SizedBox(width: 8),
          _roundBtn(
            Icons.delete_sweep_outlined,
            _visible.isEmpty ? null : _clearAll,
            tooltip: 'Clear all',
          ),
        ],
      ),
    );
  }

  // ---------- filter chips ----------
  Widget _filterChips() {
    final tabs = <int>{for (final i in _alive) widget.items[i].tab}.toList()
      ..sort();

    Widget chip(String label, int? value, {Color? color}) {
      final selected = _filter == value;
      final c = color ?? ParentColors.primary;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? c : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? c : ParentColors.border),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : c)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('All', null, color: ParentColors.dark),
          chip('Unread', -1),
          for (final t in tabs) chip(_kind(t).label, t, color: _kind(t).fg),
        ],
      ),
    );
  }

  Widget _groupLabel(String text, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4, left: 2),
      child: Row(
        children: [
          Text(text.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: ParentColors.muted)),
          const SizedBox(width: 6),
          Text('$count',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ParentColors.primary)),
        ],
      ),
    );
  }

  // ---------- one notification ----------
  Widget _tile(BuildContext context, int index, bool unread) {
    final n = widget.items[index];
    final k = _kind(n.tab);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('notif_$index'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _dismiss(index),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: ParentColors.danger,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 22),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _open(index),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: unread
                      ? ParentColors.primary.withOpacity(0.35)
                      : ParentColors.border,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F14375A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: k.bg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(n.icon, size: 21, color: k.fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.text,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight:
                            unread ? FontWeight.w800 : FontWeight.w600,
                            color: ParentColors.dark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: k.bg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(k.label,
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: k.fg)),
                            ),
                            const Spacer(),
                            const Text('Open',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: ParentColors.primary)),
                            const Icon(Icons.chevron_right_rounded,
                                size: 18, color: ParentColors.primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (unread)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: ParentColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- empty state ----------
  Widget _empty(IconData icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: ParentColors.tintStrong,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: ParentColors.primary),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ParentColors.dark)),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(
                  fontSize: 12.5, color: ParentColors.muted)),
        ],
      ),
    );
  }
}