import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/page_app_bar.dart';

// =====================================================================
// Teacher · Notifications (नवीन, फुकट in-app — push नाही)
//
// Home वरच्या bell ने उघडतो. यादी live data वरून तयार होते:
//  - Parents चे न वाचलेले messages
//  - रजेचे pending अर्ज (Approve / Decline बाकी)
//  - Parent ने पाठवलेल्या payment requests (UTR verify बाकी)
//  - आजची हजेरी अजून भरलेली नाही
//
// Features: unread badge (Home bell वर), Mark all read, swipe करून काढणे
// (Undo सह), Clear all, filter chips, tap = संबंधित screen उघडतो,
// pull-to-refresh. Read / cleared नोंद या फोनमध्ये (शिक्षकानुसार) save होते.
// =====================================================================

const Color _primary = Color(0xFF168C80);
const Color _dark = Color(0xFF183B45);
const Color _muted = Color(0xFF82918D);
const Color _red = Color(0xFFE36B61);
const Color _orange = Color(0xFFD99437);
const Color _green = Color(0xFF269B73);
const Color _blue = Color(0xFF4786C7);

enum TeacherNotifKind { messages, leave, payment, attendance }

class _KindMeta {
  const _KindMeta(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

const Map<TeacherNotifKind, _KindMeta> _meta = {
  TeacherNotifKind.messages:
  _KindMeta('Messages', Icons.chat_bubble_rounded, _blue),
  TeacherNotifKind.leave:
  _KindMeta('Leave', Icons.event_note_rounded, _orange),
  TeacherNotifKind.payment:
  _KindMeta('Fees', Icons.currency_rupee_rounded, _green),
  TeacherNotifKind.attendance:
  _KindMeta('Attendance', Icons.fact_check_rounded, _red),
};

class TeacherNotifItem {
  const TeacherNotifItem({
    required this.kind,
    required this.text,
    required this.tab,
    required this.key,
  });

  final TeacherNotifKind kind;
  final String text;

  /// MainShell चा tab: 1 Attendance, 5 Messages, 7 Fees, 9 Leave
  final int tab;

  /// Read / clear ची नोंद ठेवण्यासाठी unique key.
  final String key;
}

/// Parent ची "submitted" payment request (students/{id}/payments/{id}).
class _PayReq {
  const _PayReq({
    required this.id,
    required this.studentName,
    required this.title,
    required this.amount,
    required this.utr,
    required this.createdAt,
  });

  final String id;
  final String studentName;
  final String title;
  final int amount;
  final String utr;
  final DateTime createdAt;

  factory _PayReq.fromDoc(
      String studentName, QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    final ts = x['createdAt'];
    final amt = x['amount'];
    return _PayReq(
      id: d.id,
      studentName: studentName,
      title: (x['title'] ?? '').toString(),
      amount: amt is num ? amt.toInt() : 0,
      utr: (x['utr'] ?? '').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}

String _money(int amount) {
  final s = amount.abs().toString();
  String r;
  if (s.length <= 3) {
    r = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    r = '${parts.join(',')},$last3';
  }
  return '₹$r';
}

// =====================================================================
// STORE — notifications ची यादी + read / cleared नोंद (Home आणि screen दोन्ही वापरतात)
// =====================================================================
class TeacherNotifStore extends ChangeNotifier {
  TeacherNotifStore._();

  static final TeacherNotifStore instance = TeacherNotifStore._();

  List<_PayReq> _pay = [];
  Set<String> _read = {};
  Set<String> _gone = {};
  String _prefsFor = '';
  String _lastUid = '';
  int _lastStudents = -1;
  bool _attached = false;
  bool _busy = false;
  Timer? _timer;

  /// Payment requests लोड न झाल्या (Firestore rules नसतील) तर true.
  bool payFailed = false;

  static String _readKey(String uid) => 'teacher_notif_read_$uid';
  static String _goneKey(String uid) => 'teacher_notif_gone_$uid';

  /// Home उघडल्यावर एकदा चालू करा (पुन्हा पुन्हा बोलावलं तरी चालतं).
  void start() {
    if (_attached) return;
    _attached = true;
    AppState.instance.addListener(_onApp);
    // Payment requests दर 10 मिनिटांनी पुन्हा तपासतो (reads वाचवण्यासाठी जास्त वेळा नाही).
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => refresh());
    refresh();
  }

  void _onApp() {
    final s = AppState.instance;
    if (s.uid != _lastUid || s.students.length != _lastStudents) refresh();
  }

  /// Parent च्या payment requests पुन्हा घेतो (प्रत्येक मुलाच्या `payments` मधून).
  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final s = AppState.instance;
      _lastUid = s.uid;
      _lastStudents = s.students.length;

      if (s.uid.isEmpty || !s.isTeacher) {
        _pay = [];
        _read = {};
        _gone = {};
        _prefsFor = '';
        payFailed = false;
        notifyListeners();
        return;
      }

      await _loadPrefs(s.uid);

      final students = List<ChildInfo>.of(s.students);
      final results = await Future.wait([
        for (final st in students) _payFor(st),
      ]);
      final found = <_PayReq>[];
      var failed = false;
      for (final r in results) {
        if (r == null) {
          failed = true;
        } else {
          found.addAll(r);
        }
      }
      found.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _pay = found;
      payFailed = failed;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<List<_PayReq>?> _payFor(ChildInfo st) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .doc(st.id)
          .collection('payments')
          .where('status', isEqualTo: 'submitted')
          .get();
      return [for (final d in snap.docs) _PayReq.fromDoc(st.name, d)];
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPrefs(String uid) async {
    if (_prefsFor == uid) return;
    try {
      final p = await SharedPreferences.getInstance();
      _read = (p.getStringList(_readKey(uid)) ?? const <String>[]).toSet();
      _gone = (p.getStringList(_goneKey(uid)) ?? const <String>[]).toSet();
    } catch (_) {
      _read = {};
      _gone = {};
    }
    _prefsFor = uid;
  }

  Future<void> _save() async {
    final uid = _prefsFor;
    if (uid.isEmpty) return;
    List<String> cap(Set<String> set) {
      final l = set.toList();
      return l.length > 300 ? l.sublist(l.length - 300) : l;
    }

    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_readKey(uid), cap(_read));
      await p.setStringList(_goneKey(uid), cap(_gone));
    } catch (_) {}
  }

  /// सध्याच्या live data वरून notifications (काढलेल्या वगळून).
  List<TeacherNotifItem> items(AppState s) {
    final now = DateTime.now();
    final ymd = AppState.dayKey(now);
    final out = <TeacherNotifItem>[];

    final n = s.unreadMessages;
    if (n > 0) {
      out.add(TeacherNotifItem(
        kind: TeacherNotifKind.messages,
        text: n == 1
            ? 'You have 1 unread message from a parent.'
            : 'You have $n unread messages from parents.',
        tab: 5,
        key: 'msg_${ymd}_$n',
      ));
    }

    for (final l in s.leaves.where((l) => l.isPending).take(8)) {
      final a = AppState.shortDate(l.fromDate);
      final b = AppState.shortDate(l.toDate);
      final range = a == b ? a : '$a – $b';
      out.add(TeacherNotifItem(
        kind: TeacherNotifKind.leave,
        text: '${l.studentName} · leave request for $range'
            '${l.days > 1 ? ' (${l.days} days)' : ''} is waiting for your decision.',
        tab: 9,
        key: 'leave_${l.id}',
      ));
    }

    for (final p in _pay.take(8)) {
      out.add(TeacherNotifItem(
        kind: TeacherNotifKind.payment,
        text: '${p.studentName} · parent sent a payment request '
            '${_money(p.amount)}${p.title.isEmpty ? '' : ' for ${p.title}'} '
            '(UTR ${p.utr}). Please verify.',
        tab: 7,
        key: 'pay_${p.id}',
      ));
    }

    if (!s.attendanceSaved &&
        s.students.isNotEmpty &&
        now.weekday != DateTime.sunday) {
      out.add(TeacherNotifItem(
        kind: TeacherNotifKind.attendance,
        text: 'Today’s attendance has not been marked yet.',
        tab: 1,
        key: 'att_$ymd',
      ));
    }

    return [
      for (final i in out)
        if (!_gone.contains(i.key)) i,
    ];
  }

  bool isRead(String key) => _read.contains(key);

  int unreadCount(AppState s) =>
      items(s).where((i) => !_read.contains(i.key)).length;

  void markRead(Iterable<String> keys) {
    _read.addAll(keys);
    notifyListeners();
    _save();
  }

  void clear(Iterable<String> keys) {
    _gone.addAll(keys);
    notifyListeners();
    _save();
  }

  void restore(Iterable<String> keys) {
    _gone.removeAll(keys);
    notifyListeners();
    _save();
  }
}

// =====================================================================
// SCREEN
// =====================================================================
class TeacherNotificationScreen extends StatefulWidget {
  const TeacherNotificationScreen({super.key, required this.onOpenTab});

  /// Screen बंद झाल्यावर संबंधित tab उघडायला (MainShell चा index).
  final ValueChanged<int> onOpenTab;

  @override
  State<TeacherNotificationScreen> createState() =>
      _TeacherNotificationScreenState();
}

class _TeacherNotificationScreenState extends State<TeacherNotificationScreen> {
  /// null = All, 'unread' = न वाचलेले, नाहीतर kind चं नाव.
  String? _filter;

  void _snack(String text, {String? action, VoidCallback? onAction}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          action: action == null
              ? null
              : SnackBarAction(label: action, onPressed: onAction ?? () {}),
        ),
      );
  }

  void _open(TeacherNotifItem i) {
    TeacherNotifStore.instance.markRead([i.key]);
    Navigator.of(context).pop();
    widget.onOpenTab(i.tab);
  }

  void _dismissed(TeacherNotifItem i) {
    final store = TeacherNotifStore.instance;
    store.clear([i.key]);
    _snack(
      'Notification removed',
      action: 'Undo',
      onAction: () => store.restore([i.key]),
    );
  }

  Future<void> _clearAll(List<TeacherNotifItem> all) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear all notifications?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'They will be removed from this list. Your pending work '
              '(leave, fees, messages) stays in its own screen.',
          style: TextStyle(fontSize: 13, height: 1.5, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final keys = [for (final i in all) i.key];
    final store = TeacherNotifStore.instance;
    store.clear(keys);
    _snack(
      'All notifications cleared',
      action: 'Undo',
      onAction: () => store.restore(keys),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppState.instance,
        TeacherNotifStore.instance,
      ]),
      builder: (context, _) {
        final s = AppState.instance;
        final store = TeacherNotifStore.instance;
        final all = store.items(s);
        final unread = all.where((i) => !store.isRead(i.key)).toList();

        final kindsPresent = [
          for (final k in TeacherNotifKind.values)
            if (all.any((i) => i.kind == k)) k,
        ];

        // चुकीचा filter (उदा. ती kind आता यादीत नाही) असेल तर All.
        var filter = _filter;
        if (filter != null &&
            filter != 'unread' &&
            !kindsPresent.any((k) => k.name == filter)) {
          filter = null;
        }

        final shown = all.where((i) {
          if (filter == null) return true;
          if (filter == 'unread') return !store.isRead(i.key);
          return i.kind.name == filter;
        }).toList();
        final fresh = shown.where((i) => !store.isRead(i.key)).toList();
        final earlier = shown.where((i) => store.isRead(i.key)).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: buildPageAppBar(
            title: 'Notifications',
            subtitle: unread.isEmpty
                ? 'You are all caught up'
                : '${unread.length} unread',
            onBack: () => Navigator.of(context).pop(),
            actions: [
              if (unread.isNotEmpty)
                IconButton(
                  tooltip: 'Mark all read',
                  onPressed: () => store
                      .markRead([for (final i in unread) i.key]),
                  icon: const Icon(Icons.done_all_rounded, color: _primary),
                ),
              if (all.isNotEmpty)
                IconButton(
                  tooltip: 'Clear all',
                  onPressed: () => _clearAll(all),
                  icon: const Icon(Icons.delete_sweep_rounded, color: _muted),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: store.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (all.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _chip('All', null, filter),
                              _chip(
                                unread.isEmpty
                                    ? 'Unread'
                                    : 'Unread (${unread.length})',
                                'unread',
                                filter,
                              ),
                              for (final k in kindsPresent)
                                _chip(_meta[k]!.label, k.name, filter),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (store.payFailed)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Payment requests could not be loaded. '
                                  'Please publish the latest Firestore rules.',
                              style: TextStyle(fontSize: 11, color: _red),
                            ),
                          ),
                        if (all.isEmpty)
                          _empty()
                        else if (shown.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(
                              child: Text(
                                'No notifications match this filter.',
                                style: TextStyle(fontSize: 12, color: _muted),
                              ),
                            ),
                          )
                        else ...[
                            if (fresh.isNotEmpty) ...[
                              _header('New'),
                              for (final i in fresh) _tile(i, unread: true),
                            ],
                            if (earlier.isNotEmpty) ...[
                              _header('Earlier'),
                              for (final i in earlier) _tile(i, unread: false),
                            ],
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _empty() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        Icon(Icons.notifications_none_rounded, size: 46, color: _muted),
        SizedBox(height: 12),
        Text(
          'No notifications',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Leave requests, parent messages, payment requests\n'
              'and attendance reminders will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, height: 1.5, color: _muted),
        ),
      ],
    ),
  );

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: _dark,
      ),
    ),
  );

  Widget _chip(String label, String? value, String? current) => ChoiceChip(
    label: Text(label),
    selected: current == value,
    showCheckmark: false,
    selectedColor: _primary,
    backgroundColor: const Color(0xFFE4F3EF),
    side: BorderSide.none,
    labelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: current == value ? Colors.white : _primary,
    ),
    onSelected: (_) => setState(() => _filter = value),
  );

  Widget _tile(TeacherNotifItem i, {required bool unread}) {
    final m = _meta[i.kind]!;
    return Dismissible(
      key: ValueKey(i.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _dismissed(i),
      background: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: unread ? Colors.white : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread ? m.color.withValues(alpha: 0.35) : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: () => _open(i),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: m.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(m.icon, color: m.color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.text,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight:
                          unread ? FontWeight.w700 : FontWeight.w500,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: m.color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: m.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(top: 4, left: 8),
                    height: 9,
                    width: 9,
                    decoration: const BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}