import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/parent_widgets.dart';
import 'parent_attendance_screen.dart';
import 'parent_calendar_screen.dart';
import 'parent_leave_screen.dart';
import 'parent_message_screen.dart';
import 'parent_notification_screen.dart';

/// Colour palette of the Parent app (cream page background).
/// parent_shell.dart also uses this, so the tabs match the Home screen.
class ParentColors {
  static const Color dark = Color(0xFF14375A);
  static const Color primary = Color(0xFF2B8FDB);
  static const Color primaryLight = Color(0xFF4FB3F2);
  static const Color muted = Color(0xFF6B8399);
  // Page background = the same cream colour as the rest of the app.
  static const Color pageBg = Color(0xFFFFF8F1);
  static const Color skyTop = Color(0xFFFFF8F1);
  static const Color border = Color(0xFFD3E6F5);
  static const Color tint = Color(0xFFE6F3FD);
  static const Color tintStrong = Color(0xFFDCEEFC);
  static const Color gold = Color(0xFFF2B233);
  static const Color danger = Color(0xFFE0533D);
}

/// Same cream page background as the Home / tab screens.
/// Wrap a pushed screen's Scaffold (with backgroundColor: Colors.transparent)
/// so Calendar, Message, Profile ... all share one background.
class ParentPageBackground extends StatelessWidget {
  const ParentPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ParentColors.skyTop, ParentColors.pageBg],
            stops: [0.0, 0.45],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// नवीन: School ने दिलेला payment चा निकाल (verified / rejected) — notification साठी.
class _PayResult {
  const _PayResult({
    required this.id,
    required this.title,
    required this.amount,
    required this.status,
    required this.note,
    required this.at,
  });

  final String id;
  final String title;
  final int amount;

  /// verified | rejected
  final String status;
  final String note;
  final DateTime at;

  bool get verified => status == 'verified';
}

/// P1 · Parent Home (light-blue redesign)
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({
    super.key,
    required this.onNavigate,
    required this.onLogout,
  });

  final ValueChanged<int> onNavigate; // 0 Home, 1 Photos, 2 Diary, 3 Circulars, 4 Fees, 5 Messages
  final VoidCallback onLogout;

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _heroAsset = 'assets/images/parent_splash_pencil.png';

  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      animationBehavior: AnimationBehavior.preserve,
    )..forward();
    _loadNotifs();
    _startPayWatch();
  }

  @override
  void dispose() {
    _paySub?.cancel();
    _intro.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // नवीन: payment request चा निकाल (Teacher / Admin ने Verify किंवा Reject केल्यावर)
  // ---------------------------------------------------------------
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paySub;
  String _payChildId = '';
  List<_PayResult> _payResults = [];

  void _startPayWatch() {
    final id = AppState.instance.child.id;
    if (id.isEmpty || id == _payChildId) return;
    _paySub?.cancel();
    _payChildId = id;
    _paySub = FirebaseFirestore.instance
        .collection('students')
        .doc(id)
        .collection('payments')
        .snapshots()
        .listen(
          (snap) {
        final list = <_PayResult>[];
        for (final d in snap.docs) {
          final x = d.data();
          final st = (x['status'] ?? '').toString();
          if (st != 'verified' && st != 'rejected') continue;
          final r = x['reviewedAt'];
          final c = x['createdAt'];
          final at = r is Timestamp
              ? r.toDate()
              : (c is Timestamp ? c.toDate() : DateTime.now());
          final amt = x['amount'];
          list.add(_PayResult(
            id: d.id,
            title: (x['title'] ?? '').toString(),
            amount: amt is num ? amt.toInt() : 0,
            status: st,
            note: (x['note'] ?? '').toString().trim(),
            at: at,
          ));
        }
        list.sort((a, b) => b.at.compareTo(a.at));
        if (mounted) setState(() => _payResults = list);
      },
      // rules / network चुकले तरी Home चालू राहतो (फक्त ही सूचना येत नाही).
      onError: (Object _) {},
    );
  }

  Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Notification screen मध्ये read / clear केलेल्या (फोन मध्ये save केलेल्या) बाबी.
  Set<String> _hiddenNotifs = {};

  Future<void> _loadNotifs() async {
    final h = await ParentNotifStore.hidden(AppState.instance.child.id);
    if (mounted) setState(() => _hiddenNotifs = h);
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (s.child.id.isNotEmpty && s.child.id != _payChildId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startPayWatch();
          });
        }
        final now = DateTime.now();
        final todayPhotos = s.childPhotosOn(now);
        final post = s.diaryFor(now);
        final circulars = s.visibleCirculars;
        final latest = circulars.isEmpty ? null : circulars.first;
        final due = s.nextDueFee;
        final notifs = _notifs(s);
        final today = DateTime(now.year, now.month, now.day);
        final upcoming = s.events
            .where((e) => !e.date.isBefore(today))
            .take(3)
            .toList();
        final msgs = s.thread(s.child.id);
        final lastMsg = msgs.isEmpty ? null : msgs.last;

        final sections = <Widget>[
          _header(context, s, notifs),
          // बदल: Hero card आता tap करता येत नाही (Attendance आता quick-action मधून उघडतो).
          _heroCard(s),
          _glance(s, todayPhotos.length, post != null),
          _quickActions(context, due != null, s.unreadMessages > 0),
          if (s.pendingAckCount > 0) _ackBanner(s.pendingAckCount),
          if (due != null) _feeBanner(due, today),
          // नवीन: रजेच्या अर्जाची स्थिती
          if (_latestLeave(s) != null) _leaveCard(context, _latestLeave(s)!),
          _photosCard(s, todayPhotos),
          _diaryCard(post),
          _eventsCard(context, upcoming),
          _messageCard(context, lastMsg),
          _circularCard(s, latest),
          if (s.child.pickupNote.trim().isNotEmpty) _pickupCard(s),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
          children: [
            for (var i = 0; i < sections.length; i++)
              _Reveal(
                controller: _intro,
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: sections[i],
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // DATA HELPERS
  // ---------------------------------------------------------------
  List<ParentNotifItem> _notifs(AppState s) {
    final now = DateTime.now();
    final ymd = AppState.dayKey(now);
    final out = <ParentNotifItem>[];

    // Teacher चे न वाचलेले messages (आधी notifications मध्ये येत नव्हते).
    final unreadMsgs = s.unreadMessages;
    if (unreadMsgs > 0) {
      final msgs = s.thread(s.child.id);
      final lastId = msgs.isEmpty ? '' : msgs.last.id;
      out.add(ParentNotifItem(
        Icons.chat_bubble_rounded,
        unreadMsgs == 1
            ? 'You have 1 new message from the teacher.'
            : 'You have $unreadMsgs new messages from the teacher.',
        5,
        key: 'msg_$lastId',
      ));
    }
    if (s.diaryFor(now) != null) {
      out.add(ParentNotifItem(
        Icons.menu_book_rounded,
        'Today’s class diary is published.',
        2,
        key: 'diary_$ymd',
      ));
    }
    final photoCount = s.childPhotosOn(now).length;
    if (photoCount > 0) {
      out.add(ParentNotifItem(
        Icons.photo_library_rounded,
        'New photos of ${s.child.firstName} were shared.',
        1,
        key: 'photos_${ymd}_$photoCount',
      ));
    }
    for (final c in s.visibleCirculars.where(s.isNewCircular).take(3)) {
      out.add(ParentNotifItem(
        Icons.campaign_rounded,
        'New circular: ${c.title}',
        3,
        key: 'circ_${c.id.isEmpty ? c.title : c.id}',
      ));
    }
    final due = s.nextDueFee;
    if (due != null) {
      final date = due.dueDate == null
          ? ''
          : ' due by ${AppState.shortDate(due.dueDate!)}';
      out.add(ParentNotifItem(
        Icons.currency_rupee_rounded,
        '${due.title} ${rupees(due.amount)}$date.',
        4,
        key: 'fee_${due.id.isEmpty ? due.title : due.id}',
      ));
    }
    // नवीन: रजेच्या अर्जाचा निर्णय (Teacher ने Approve / Decline केल्यावर).
    for (final l in s.leaves.where((l) => !l.isPending).take(3)) {
      final range = _leaveRange(l);
      out.add(ParentNotifItem(
        l.isApproved ? Icons.event_available_rounded : Icons.event_busy_rounded,
        l.isApproved
            ? 'Leave for $range was approved.'
            : 'Leave for $range was declined.',
        6,
        key: 'leave_${l.id}_${l.status}',
      ));
    }
    // नवीन: payment चा निकाल (गेल्या 30 दिवसांतले, जास्तीत जास्त 3).
    final recent = now.subtract(const Duration(days: 30));
    for (final p in _payResults.where((p) => p.at.isAfter(recent)).take(3)) {
      final what = p.title.isEmpty ? '' : ' for ${p.title}';
      out.add(ParentNotifItem(
        p.verified ? Icons.verified_rounded : Icons.cancel_rounded,
        p.verified
            ? 'Your payment of ${rupees(p.amount)}$what was verified by the school.'
            : 'Your payment request of ${rupees(p.amount)}$what could not be verified.'
            '${p.note.isEmpty ? '' : ' School note: ${p.note}'}',
        4,
        key: 'pay_${p.id}_${p.status}',
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------
  // LEAVE HELPERS (नवीन)
  // ---------------------------------------------------------------
  String _leaveRange(LeaveRequest l) {
    final a = AppState.shortDate(l.fromDate);
    final b = AppState.shortDate(l.toDate);
    return a == b ? a : '$a – $b';
  }

  /// Home वर दाखवायचा रजेचा अर्ज: pending किंवा (न वाचलेला) निर्णय झालेला,
  /// ज्याची शेवटची तारीख अजून गेलेली नाही.
  LeaveRequest? _latestLeave(AppState s) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    for (final l in s.leaves) {
      final end = DateTime(l.toDate.year, l.toDate.month, l.toDate.day);
      if (end.isBefore(today)) continue;
      if (!l.isPending && _hiddenNotifs.contains('leave_${l.id}_${l.status}')) {
        continue;
      }
      return l;
    }
    return null;
  }

  Widget _leaveCard(BuildContext context, LeaveRequest l) {
    final Color fg;
    final Color bg;
    final String label;
    final IconData icon;
    if (l.isApproved) {
      fg = const Color(0xFF22A06B);
      bg = const Color(0xFFE3F6EC);
      label = 'Approved';
      icon = Icons.event_available_rounded;
    } else if (l.isDeclined) {
      fg = ParentColors.danger;
      bg = const Color(0xFFFFE7E5);
      label = 'Declined';
      icon = Icons.event_busy_rounded;
    } else {
      fg = const Color(0xFFB7791F);
      bg = const Color(0xFFFFF6DD);
      label = 'Pending';
      icon = Icons.hourglass_top_rounded;
    }
    return _Tap(
      onTap: () => _push(context, const ParentLeaveScreen()),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave · ${_leaveRange(l)} (${l.days} day${l.days == 1 ? '' : 's'})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ParentColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.teacherNote.trim().isNotEmpty
                        ? 'Teacher: ${l.teacherNote.trim()}'
                        : l.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: ParentColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ---------------------------------------------------------------
  // SMALL BUILDING BLOCKS
  // ---------------------------------------------------------------
  BoxDecoration _cardDecoration({Color color = Colors.white}) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: ParentColors.border),
    boxShadow: const [
      BoxShadow(
        color: Color(0x142B8FDB),
        blurRadius: 12,
        offset: Offset(0, 5),
      ),
    ],
  );

  Widget _card({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    Color color = Colors.white,
  }) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: _cardDecoration(color: color),
      child: child,
    );
    return onTap == null ? box : _Tap(onTap: onTap, child: box);
  }

  Widget _sectionTitle(IconData icon, String title,
      {String? action, VoidCallback? onAction, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: ParentColors.dark,
              ),
            ),
          ),
          if (trailing != null) trailing,
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: ParentColors.primary,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 15, color: ParentColors.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyNote(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF9DB6CA)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: ParentColors.muted,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration:
    BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(
      text,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg),
    ),
  );

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  // ---------------------------------------------------------------
  // 1. HEADER
  // ---------------------------------------------------------------
  Widget _header(BuildContext context, AppState s, List<ParentNotifItem> notifs) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()},',
                style: const TextStyle(
                  fontSize: 11,
                  color: ParentColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      s.child.parentFirstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                        color: ParentColors.dark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.waving_hand_rounded,
                      size: 17, color: ParentColors.gold),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                AppState.dateLabel(DateTime.now()),
                style: const TextStyle(
                  fontSize: 10,
                  color: ParentColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
        _RoundButton(
          icon: Icons.notifications_none_rounded,
          badge: notifs.where((n) => !_hiddenNotifs.contains(n.key)).length,
          onTap: () => _push(
            context,
            ParentNotificationScreen(
              items: notifs,
              onOpenTab: widget.onNavigate,
            ),
          ).then((_) => _loadNotifs()),
        ),
        const SizedBox(width: 8),
        _RoundButton(
          icon: Icons.logout_rounded,
          tooltip: 'Logout',
          iconColor: ParentColors.muted,
          onTap: widget.onLogout,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // 2. CHILD HERO CARD
  // ---------------------------------------------------------------
  Widget _heroCard(AppState s) {
    final c = s.child;
    final code = s.childAttendanceCode;

    String label;
    Color dot;
    switch (code) {
      case 'P':
        label = 'Present today';
        dot = const Color(0xFF22A06B);
        break;
      case 'L':
        label = 'Late today';
        dot = const Color(0xFFE5A100);
        break;
      case 'A':
        label = 'Absent today';
        dot = const Color(0xFFE0533D);
        break;
      default:
        label = 'Not marked yet';
        dot = const Color(0xFF9DB0C0);
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
            color: Color(0x552B8FDB),
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
            Positioned(
              right: 8,
              top: 4,
              bottom: 4,
              child: Center(
                child: Image.asset(
                  _heroAsset,
                  width: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 136),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 152, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
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
                            initialsOf(c.name),
                            style: const TextStyle(
                              fontSize: 14.5,
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
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.className} · Roll No. ${c.rollNo}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: dot, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: ParentColors.dark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            c.ageLabel(DateTime.now()),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // 3. TODAY AT A GLANCE
  // ---------------------------------------------------------------
  Widget _glance(AppState s, int photoCount, bool diaryDone) {
    Widget stat(IconData icon, String value, String label, int tab,
        {bool highlight = false}) {
      return Expanded(
        child: _Tap(
          onTap: () => widget.onNavigate(tab),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: highlight
                        ? ParentColors.primary
                        : ParentColors.tint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                      size: 14,
                      color: highlight ? Colors.white : ParentColors.primary),
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: ParentColors.dark,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ParentColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final unread = s.unreadCircularCount;
    return Row(
      children: [
        stat(Icons.photo_library_rounded, '$photoCount', 'Photos today', 1,
            highlight: photoCount > 0),
        const SizedBox(width: 8),
        stat(Icons.menu_book_rounded, diaryDone ? 'Published' : 'Pending',
            'Class diary', 2,
            highlight: diaryDone),
        const SizedBox(width: 8),
        stat(Icons.campaign_rounded, '$unread', 'New circulars', 3,
            highlight: unread > 0),
      ],
    );
  }

  // ---------------------------------------------------------------
  // 4. QUICK ACTIONS
  // ---------------------------------------------------------------
  Widget _quickActions(BuildContext context, bool feeDue, bool msgUnread) {
    Widget item(IconData icon, String label, VoidCallback onTap,
        {bool dot = false}) {
      return Expanded(
        child: _Tap(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: ParentColors.tint,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, color: ParentColors.primary, size: 18),
                    ),
                    if (dot)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: ParentColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item(Icons.calendar_month_rounded, 'Calendar',
                () => _push(context, const ParentCalendarScreen())),
        const SizedBox(width: 8),
        item(Icons.chat_bubble_rounded, 'Message',
                () => _push(context, const ParentMessageScreen()),
            dot: msgUnread),
        const SizedBox(width: 8),
        // बदल: तिसरा tab 'Profile' ऐवजी 'Attendance' (Profile bottom bar मध्ये आहेच).
        item(Icons.how_to_reg_rounded, 'Attendance',
                () => _push(context, const ParentAttendanceScreen())),
        const SizedBox(width: 8),
        item(Icons.currency_rupee_rounded, 'Fees', () => widget.onNavigate(4),
            dot: feeDue),
        // नवीन: रजेचा अर्ज
        const SizedBox(width: 8),
        item(Icons.event_busy_rounded, 'Leave',
                () => _push(context, const ParentLeaveScreen()),
            dot: AppState.instance.leaves.any((l) =>
            !l.isPending &&
                !_hiddenNotifs.contains('leave_${l.id}_${l.status}'))),
      ],
    );
  }

  // ---------------------------------------------------------------
  // 5. BANNERS (acknowledgement + fee reminder)
  // ---------------------------------------------------------------
  Widget _ackBanner(int count) {
    return _Tap(
      onTap: () => widget.onNavigate(3),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6DD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF2D58A)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: ParentColors.gold.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mark_email_unread_rounded,
                  size: 16, color: Color(0xFFB7791F)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count == 1
                    ? '1 circular needs your acknowledgement'
                    : '$count circulars need your acknowledgement',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7A5210),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFFB7791F)),
          ],
        ),
      ),
    );
  }

  Widget _feeBanner(FeeItem due, DateTime today) {
    String when = 'Payment pending';
    if (due.dueDate != null) {
      final d = DateTime(due.dueDate!.year, due.dueDate!.month, due.dueDate!.day);
      final days = d.difference(today).inDays;
      if (days < 0) {
        when = 'Overdue by ${-days} day${-days == 1 ? '' : 's'}';
      } else if (days == 0) {
        when = 'Due today';
      } else {
        when = '$days day${days == 1 ? '' : 's'} left · '
            'due ${AppState.shortDate(due.dueDate!)}';
      }
    }

    return _Tap(
      onTap: () => widget.onNavigate(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [ParentColors.dark, Color(0xFF2468A8)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3314375A),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.currency_rupee_rounded,
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${due.title} · ${rupees(due.amount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    when,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: .85),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: ParentColors.dark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // 6. PHOTOS
  // ---------------------------------------------------------------
  Widget _photosCard(AppState s, List<SharedPhoto> photos) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.photo_library_rounded,
            'Photos of ${s.child.firstName} · Today',
            action: 'See all',
            onAction: () => widget.onNavigate(1),
          ),
          if (photos.isEmpty)
            _emptyNote(Icons.image_outlined, 'No photos shared today yet.')
          else
          // बदल: नेहमी 3 जागा (slots). 1 किंवा 2 फोटो असले तरी प्रत्येक फोटो
          // तेवढ्याच (एक-तृतीयांश रुंदीच्या) आकारात दिसतो — एकटा फोटो मोठा होत नाही.
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: i >= photos.length
                        ? const SizedBox.shrink()
                        : AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // बदल: खरा फोटो दाखवतो (रंगीत box + icon नाही).
                          GestureDetector(
                            onTap: () => widget.onNavigate(1),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _photoThumb(photos[i]),
                            ),
                          ),
                          if (i == 2 && photos.length > 3)
                            IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: ParentColors.dark
                                      .withValues(alpha: .55),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '+${photos.length - 3}',
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // Teacher चा फोटो 'data:image/jpeg;base64,...' (Spark plan) किंवा http link असू शकतो.
  // फोटो नसेल / उघडला नाही तर आधीचा रंगीत placeholder दाखवतो.
  static final Map<String, Uint8List> _thumbCache = {};

  Widget _photoThumb(SharedPhoto p) {
    final placeholder = PhotoTile(colorIndex: p.colorIndex);
    final u = p.url;
    if (u == null || u.isEmpty) return placeholder;

    if (u.startsWith('data:')) {
      Uint8List? bytes = _thumbCache[u];
      if (bytes == null) {
        try {
          bytes = UriData.parse(u).contentAsBytes();
          if (_thumbCache.length > 40) _thumbCache.clear();
          _thumbCache[u] = bytes;
        } catch (_) {
          return placeholder;
        }
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Image.network(
      u,
      fit: BoxFit.cover,
      loadingBuilder: (ctx, child, progress) =>
      progress == null ? child : placeholder,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  // ---------------------------------------------------------------
  // 7. TODAY'S DIARY
  // ---------------------------------------------------------------
  Widget _diaryCard(DiaryPost? post) {
    return _card(
      onTap: () => widget.onNavigate(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.menu_book_rounded,
            'Today’s class diary',
            trailing: (post?.mood != null && post!.mood!.trim().isNotEmpty)
                ? _pill('Mood: ${post.mood}', ParentColors.tint,
                ParentColors.primary)
                : null,
          ),
          if (post == null)
            _emptyNote(Icons.hourglass_empty_rounded,
                'Teacher has not published today’s diary yet.')
          else ...[
            for (final line in post.items.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ParentColors.tint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        line.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          line.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: ParentColors.dark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (post.items.length > 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '+${post.items.length - 3} more activities',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ParentColors.primary,
                  ),
                ),
              ),
            if (post.bring.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.backpack_rounded,
                        size: 15, color: ParentColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Send ${post.bring.join(', ')} tomorrow',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (post.homeNote.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.home_rounded,
                      size: 14, color: ParentColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      post.homeNote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: ParentColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // 8. UPCOMING EVENTS
  // ---------------------------------------------------------------
  Widget _eventsCard(BuildContext context, List<SchoolEvent> events) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.event_rounded,
            'Upcoming events',
            action: 'Calendar',
            onAction: () => _push(context, const ParentCalendarScreen()),
          ),
          if (events.isEmpty)
            _emptyNote(Icons.event_available_rounded,
                'No upcoming events right now.')
          else
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _eventRow(context, events[i]),
            ],
        ],
      ),
    );
  }

  Widget _eventRow(BuildContext context, SchoolEvent e) {
    final bg = kCategoryBg[e.category] ?? ParentColors.tint;
    final fg = kCategoryFg[e.category] ?? ParentColors.primary;
    return _Tap(
      onTap: () => _push(context, const ParentCalendarScreen()),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: ParentColors.tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                Text(
                  '${e.date.day}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.primary,
                  ),
                ),
                Text(
                  AppState.monthShort(e.date.month).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.muted,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _pill(e.category, bg, fg),
                    const SizedBox(width: 8),
                    Text(
                      AppState.relativeDay(e.date),
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ParentColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // 9. LATEST MESSAGE
  // ---------------------------------------------------------------
  Widget _messageCard(BuildContext context, ChatMessage? last) {
    return _card(
      onTap: () => _push(context, const ParentMessageScreen()),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ParentColors.tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.chat_bubble_rounded,
                color: ParentColors.primary, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Message teacher',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.dark,
                        ),
                      ),
                    ),
                    if (last != null && last.time.isNotEmpty)
                      Text(
                        last.time,
                        style: const TextStyle(
                          fontSize: 9,
                          color: ParentColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  last == null
                      ? 'Tap to start a chat with the class teacher.'
                      : '${last.fromTeacher ? 'Teacher' : 'You'}: ${last.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: ParentColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: ParentColors.muted),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // 10. LATEST CIRCULAR
  // ---------------------------------------------------------------
  Widget _circularCard(AppState s, CircularRecord? latest) {
    if (latest == null) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(Icons.campaign_rounded, 'Latest circular'),
            _emptyNote(Icons.description_outlined, 'No circulars yet.'),
          ],
        ),
      );
    }
    final bg = kCategoryBg[latest.category] ?? ParentColors.tint;
    final fg = kCategoryFg[latest.category] ?? ParentColors.primary;
    final isNew = s.isNewCircular(latest);

    return _card(
      onTap: () => widget.onNavigate(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.campaign_rounded,
            'Latest circular',
            action: 'All circulars',
            onAction: () => widget.onNavigate(3),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  latest.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark,
                  ),
                ),
              ),
              if (isNew) ...[
                const SizedBox(width: 8),
                _pill('NEW', ParentColors.danger, Colors.white),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _pill(latest.category, bg, fg),
              const SizedBox(width: 8),
              Text(
                AppState.relativeDay(latest.sentAt),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ParentColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // 11. PICKUP INFO
  // ---------------------------------------------------------------
  Widget _pickupCard(AppState s) {
    return _card(
      color: ParentColors.tint,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_walk_rounded,
                color: ParentColors.primary, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pickup information',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.child.pickupNote,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: ParentColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SMALL REUSABLE WIDGETS
// =====================================================================

/// Fade + slide-up entrance, one after the other (staggered).
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.controller,
    required this.index,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final start = (index * 0.07).clamp(0.0, 0.6);
        final t = Curves.easeOutCubic
            .transform(((controller.value - start) / 0.4).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Gives any card a small "press" (shrink) effect when tapped.
class _Tap extends StatefulWidget {
  const _Tap({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Round white icon button used in the header (bell + logout).
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.tooltip,
    this.iconColor = ParentColors.dark,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final String? tooltip;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final button = _Tap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
            child: Icon(icon, color: iconColor, size: 18),
          ),
          if (badge > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ParentColors.danger,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}