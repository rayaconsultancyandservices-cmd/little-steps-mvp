import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/parent_widgets.dart';
import 'parent_home_screen.dart' show ParentColors;

/// P4 · Circulars  (Teacher ने पाठवलेले circulars इथे येतात)
///
/// Features:
///  - Summary header (unread / action needed count) + "Mark all read"
///  - Search by title / message
///  - Filter chips: All, Unread, Important, Action
///  - Grouped list: Today, This week, Earlier
///  - Pull to refresh
///  - Detail sheet with copy, event date, attachment, acknowledge button
class ParentCircularsScreen extends StatefulWidget {
  const ParentCircularsScreen({super.key, this.onBack});

  /// Back arrow action. By default it goes back to Home
  /// (the shell handles the system back for the tabs).
  final VoidCallback? onBack;

  @override
  State<ParentCircularsScreen> createState() => _ParentCircularsScreenState();
}

enum _Filter { all, unread, important, action }

class _ParentCircularsScreenState extends State<ParentCircularsScreen> {
  final TextEditingController _search = TextEditingController();
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------- helpers ----------
  bool _isUnread(AppState s, CircularRecord c) => !s.readCirculars.contains(c);

  bool _needsAction(AppState s, CircularRecord c) =>
      c.needsAck && !s.isAcked(c);

  List<CircularRecord> _apply(AppState s, List<CircularRecord> all) {
    final q = _query.trim().toLowerCase();
    return all.where((c) {
      switch (_filter) {
        case _Filter.all:
          break;
        case _Filter.unread:
          if (!_isUnread(s, c)) return false;
          break;
        case _Filter.important:
          if (!c.important) return false;
          break;
        case _Filter.action:
          if (!_needsAction(s, c)) return false;
          break;
      }
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.message.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q);
    }).toList();
  }

  String _groupOf(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff < 7) return 'This week';
    return 'Earlier';
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final all = s.visibleCirculars;
        final list = _apply(s, all);

        final unreadCount = all.where((c) => _isUnread(s, c)).length;
        final actionCount = all.where((c) => _needsAction(s, c)).length;

        // Group while keeping the newest-first order.
        final groups = <String, List<CircularRecord>>{};
        for (final c in list) {
          groups.putIfAbsent(_groupOf(c.sentAt), () => []).add(c);
        }

        return Column(
          children: [
            _header(s, all, unreadCount, actionCount),
            Expanded(
              child: RefreshIndicator(
                color: ParentColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    if (all.isNotEmpty) ...[
                      _searchBar(),
                      const SizedBox(height: 12),
                      _filterChips(all, s, unreadCount, actionCount),
                      const SizedBox(height: 16),
                    ],
                    if (all.isEmpty)
                      _emptyState(
                        Icons.description_outlined,
                        'No circulars yet',
                        'Notices from your teacher will appear here.',
                      )
                    else if (list.isEmpty)
                      _emptyState(
                        Icons.search_off_rounded,
                        'Nothing found',
                        'Try a different search or filter.',
                      )
                    else
                      for (final entry in groups.entries) ...[
                        _groupLabel(entry.key),
                        for (final c in entry.value) _card(context, s, c),
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

  // ---------- header (back arrow + title + mark all read) ----------
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

  Widget _header(
      AppState s, List<CircularRecord> all, int unreadCount, int actionCount) {
    final subtitle = all.isEmpty
        ? 'No notices'
        : unreadCount == 0 && actionCount == 0
        ? 'You are all caught up'
        : [
      if (unreadCount > 0) '$unreadCount unread',
      if (actionCount > 0) '$actionCount need action',
    ].join(' · ');

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Circulars',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
            Icons.done_all_rounded,
            unreadCount == 0
                ? null
                : () {
              for (final c in all) {
                s.markCircularRead(c);
              }
              showSnack(context, 'All circulars marked as read');
            },
            tooltip: 'Mark all read',
          ),
        ],
      ),
    );
  }

  // ---------- search ----------
  Widget _searchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13.5, color: AppColors.text),
        decoration: InputDecoration(
          hintText: 'Search circulars',
          hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.muted),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: AppColors.muted),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.muted),
            onPressed: () {
              _search.clear();
              setState(() => _query = '');
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  // ---------- filters ----------
  Widget _filterChips(
      List<CircularRecord> all, AppState s, int unreadCount, int actionCount) {
    final importantCount = all.where((c) => c.important).length;

    Widget chip(_Filter f, String label, [int? count]) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(count != null && count > 0 ? '$label · $count' : label),
          selected: selected,
          onSelected: (_) => setState(() => _filter = f),
          showCheckmark: false,
          backgroundColor: Colors.white,
          selectedColor: ParentColors.primary,
          side: BorderSide(
              color: selected ? ParentColors.primary : AppColors.border),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(_Filter.all, 'All'),
          chip(_Filter.unread, 'Unread', unreadCount),
          chip(_Filter.important, 'Important', importantCount),
          chip(_Filter.action, 'Action', actionCount),
        ],
      ),
    );
  }

  Widget _groupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.muted,
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
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
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  // ---------- list card ----------
  Widget _card(BuildContext context, AppState s, CircularRecord c) {
    final unread = _isUnread(s, c);
    final needsAction = _needsAction(s, c);
    final bg = kCategoryBg[c.category] ?? AppColors.blueLight;
    final fg = kCategoryFg[c.category] ?? AppColors.primary;
    final icon = kCategoryIcon[c.category] ?? Icons.campaign_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(context, s, c),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: unread
                    ? ParentColors.primary.withOpacity(0.35)
                    : AppColors.border,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F14375A),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 22, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          if (c.important) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.priority_high_rounded,
                                size: 16, color: Color(0xFFD9564F)),
                          ],
                          if (unread) ...[
                            const SizedBox(width: 6),
                            const StatusChip('NEW',
                                bg: ParentColors.danger, fg: Colors.white),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.message.isEmpty
                            ? c.category
                            : AppState.firstLine(c.message, 90),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(c.category, bg: bg, fg: fg),
                          if (c.eventDate != null)
                            _meta(Icons.event_rounded,
                                AppState.shortDate(c.eventDate!)),
                          if (c.attachment != null)
                            _meta(Icons.attach_file_rounded, 'Attachment'),
                          if (needsAction)
                            const StatusChip('Action needed',
                                bg: AppColors.orangeLight,
                                fg: Color(0xFFD9822B)),
                          if (c.needsAck && s.isAcked(c))
                            const StatusChip('Acknowledged',
                                bg: AppColors.primaryLight,
                                fg: AppColors.primary),
                          _meta(Icons.schedule_rounded,
                              AppState.relativeDay(c.sentAt)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ---------- detail sheet ----------
  void _open(BuildContext context, AppState s, CircularRecord c) {
    s.markCircularRead(c);

    final bg = kCategoryBg[c.category] ?? AppColors.blueLight;
    final fg = kCategoryFg[c.category] ?? AppColors.primary;
    final icon = kCategoryIcon[c.category] ?? Icons.campaign_rounded;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
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
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatusChip(c.category, bg: bg, fg: fg),
                        if (c.important)
                          const StatusChip('Important',
                              bg: AppColors.redLight,
                              fg: Color(0xFFD9564F)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: '${c.title}\n\n${c.message}',
                      ));
                      showSnack(context, 'Circular copied');
                    },
                    icon: const Icon(Icons.copy_rounded,
                        size: 20, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                c.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'From ${s.teacherName} · ${AppState.dateLabel(c.sentAt)}, '
                    '${AppState.timeLabel(c.sentAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                'Sent to ${c.audience}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  c.message.isEmpty ? 'No additional message.' : c.message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (c.eventDate != null) ...[
                const SizedBox(height: 12),
                _infoTile(
                  icon: Icons.event_rounded,
                  iconBg: ParentColors.tintStrong,
                  iconFg: ParentColors.primary,
                  title: 'Event date',
                  value: AppState.dateLabel(c.eventDate!),
                ),
              ],
              if (c.attachment != null) ...[
                const SizedBox(height: 12),
                _infoTile(
                  icon: Icons.picture_as_pdf_rounded,
                  iconBg: AppColors.redLight,
                  iconFg: const Color(0xFFD9564F),
                  title: 'Attachment',
                  value: c.attachment!,
                  trailing: TextButton(
                    onPressed: () => showSnack(
                      context,
                      'Attachment will open once file storage is connected.',
                    ),
                    child: const Text('Open',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
              // Teacher ने "Ask for acknowledgement" ON केलं असेल तर
              // Parent ला "I have read this" button दिसतो.
              if (c.needsAck) ...[
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: s,
                  builder: (ctx, _) {
                    final done = s.isAcked(c);
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: done
                          ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 20, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Acknowledged',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                          ],
                        ),
                      )
                          : ElevatedButton.icon(
                        onPressed: () {
                          s.acknowledgeCircular(c);
                          showSnack(context,
                              'Thank you! Teacher knows you have read this.');
                        },
                        icon: const Icon(Icons.done_all_rounded,
                            size: 20),
                        label: const Text('I have read this',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParentColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    required String value,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}