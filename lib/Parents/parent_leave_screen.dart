import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'parent_home_screen.dart' show ParentColors, ParentPageBackground;

/// Parent · Leave application (रजेचा अर्ज)
///
///  - Back arrow (same as the other Parent screens)
///  - मुलाचं नाव + class teacher दाखवणारं info card
///  - Form: leave type (icon chips), quick date shortcuts, from / to date,
///    दिवसांची live संख्या, reason, Send
///  - त्याच तारखांना आधीच अर्ज असेल तर सूचना + duplicate अर्ज रोखतो
///  - "My applications": Pending / Approved / Declined filter (count सह),
///    रंगीत status card, अर्ज केल्याची तारीख, Teacher ची note,
///    pending अर्ज मागे घेण्याचं बटण
/// अर्ज Firestore मार्फत Teacher च्या Leave screen मध्ये लगेच दिसतो.
class ParentLeaveScreen extends StatefulWidget {
  const ParentLeaveScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ParentLeaveScreen> createState() => _ParentLeaveScreenState();
}

class _ReasonType {
  const _ReasonType(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ParentLeaveScreenState extends State<ParentLeaveScreen> {
  static const List<_ReasonType> _types = [
    _ReasonType('Fever / not well', Icons.thermostat_rounded),
    _ReasonType('Doctor visit', Icons.medical_services_rounded),
    _ReasonType('Family function', Icons.celebration_rounded),
    _ReasonType('Out of station', Icons.flight_takeoff_rounded),
    _ReasonType('Other', Icons.edit_note_rounded),
  ];

  static const _approvedFg = Color(0xFF22A06B);
  static const _approvedBg = Color(0xFFE3F6EC);
  static const _pendingFg = Color(0xFFE5A100);
  static const _pendingBg = Color(0xFFFFF3D6);
  static const _declinedFg = Color(0xFFE0533D);
  static const _declinedBg = Color(0xFFFFE7E5);

  final TextEditingController _reason = TextEditingController();
  final FocusNode _reasonFocus = FocusNode();
  late DateTime _from;
  late DateTime _to;
  bool _sending = false;

  /// निवडलेला leave type (chip), नसेल तर null.
  String? _type;

  /// My applications filter: all | pending | approved | declined
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _from = _today();
    _to = _from;
  }

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  int get _days => _to.difference(_from).inDays + 1;

  /// निवडलेल्या कालावधीतील Sat / Sun ची संख्या.
  int get _weekendDays {
    var c = 0;
    for (var i = 0; i < _days; i++) {
      final d = DateTime(_from.year, _from.month, _from.day + i);
      if (d.weekday >= 6) c++;
    }
    return c;
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  /// निवडलेल्या तारखांशी जुळणारा (declined नसलेला) आधीचा अर्ज, नसेल तर null.
  LeaveRequest? _clash(AppState s) {
    for (final l in s.leaves) {
      if (l.isDeclined) continue;
      final f = DateUtils.dateOnly(l.fromDate);
      final t = DateUtils.dateOnly(l.toDate);
      if (!_to.isBefore(f) && !_from.isAfter(t)) return l;
    }
    return null;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final today = _today();
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: isFrom ? today : _from,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
      }
    });
  }

  void _setRange(DateTime from, DateTime to) {
    setState(() {
      _from = from;
      _to = to;
    });
  }

  void _pickType(_ReasonType t) {
    setState(() {
      _type = t.label;
      _reason.text = t.label == 'Other' ? '' : t.label;
      _reason.selection =
          TextSelection.collapsed(offset: _reason.text.length);
    });
    if (t.label == 'Other') _reasonFocus.requestFocus();
  }

  Future<void> _send() async {
    final s = AppState.instance;
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      _snack('Please write the reason for leave.');
      return;
    }
    if (_clash(s) != null) {
      _snack('You already have a leave application for these dates.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await s.submitLeave(from: _from, to: _to, reason: reason);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _reason.clear();
        _type = null;
        _filter = 'all';
        _from = _today();
        _to = _from;
      });
      _snack('Leave application sent to the teacher.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack('Could not send. Please try again.');
    }
  }

  Future<void> _cancel(LeaveRequest l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Withdraw application?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'The teacher will no longer see this application.',
          style: TextStyle(color: ParentColors.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ParentColors.danger),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppState.instance.cancelLeave(l.id);
      if (!mounted) return;
      _snack('Application withdrawn.');
    } catch (_) {
      if (!mounted) return;
      _snack('Could not withdraw. Please try again.');
    }
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return ParentPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: AnimatedBuilder(
                  animation: AppState.instance,
                  builder: (context, _) {
                    final s = AppState.instance;
                    final all = [...s.leaves]
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    final pending = all.where((l) => l.isPending).length;
                    final approved = all.where((l) => l.isApproved).length;
                    final declined = all.where((l) => l.isDeclined).length;
                    final list = switch (_filter) {
                      'pending' => all.where((l) => l.isPending).toList(),
                      'approved' => all.where((l) => l.isApproved).toList(),
                      'declined' => all.where((l) => l.isDeclined).toList(),
                      _ => all,
                    };

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: ListView(
                        keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          _childCard(s),
                          const SizedBox(height: 12),
                          _formCard(s),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'My applications',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: ParentColors.dark,
                                  ),
                                ),
                              ),
                              if (all.isNotEmpty)
                                Text(
                                  '${all.length} total',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: ParentColors.muted,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (all.isNotEmpty) ...[
                            _filters(all.length, pending, approved, declined),
                            const SizedBox(height: 10),
                          ],
                          if (all.isEmpty)
                            _empty('No leave applications yet',
                                'Applications you send will show up here.')
                          else if (list.isEmpty)
                            _empty('Nothing here',
                                'No $_filter applications right now.')
                          else
                            for (final l in list) _leaveCard(l),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack ?? () => Navigator.maybePop(context),
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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: ParentColors.dark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Application',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tell the teacher your child will be absent',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- child info ----------
  Widget _childCard(AppState s) {
    final name = s.child.name;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final teacher = s.teacherName.trim().isEmpty ? 'Class teacher' : s.teacherName;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ParentColors.primary, ParentColors.primaryLight],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332B8FDB),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: ParentColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Your child' : 'Leave for $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.className} · $teacher will be notified',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: .92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- form ----------
  BoxDecoration get _cardDeco => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: ParentColors.border),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: ParentColors.dark,
      ),
    ),
  );

  Widget _formCard(AppState s) {
    final clash = _clash(s);
    final today = _today();
    DateTime plus(int d) => DateTime(today.year, today.month, today.day + d);

    final shortcuts = <(String, DateTime, DateTime)>[
      ('Today', today, today),
      ('Tomorrow', plus(1), plus(1)),
      ('Next 2 days', plus(1), plus(2)),
      ('Next 3 days', plus(1), plus(3)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Reason type'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final t in _types) _typeChip(t),
            ],
          ),
          const SizedBox(height: 14),
          _label('Dates'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final sc in shortcuts)
                  _shortcutChip(sc.$1, sc.$2, sc.$3),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child:
                  _dateBox('From', _from, () => _pickDate(isFrom: true))),
              const SizedBox(width: 10),
              Expanded(
                  child: _dateBox('To', _to, () => _pickDate(isFrom: false))),
            ],
          ),
          const SizedBox(height: 10),
          _durationStrip(),
          if (clash != null) ...[
            const SizedBox(height: 8),
            _clashNote(clash),
          ],
          const SizedBox(height: 14),
          _label('Reason'),
          TextField(
            controller: _reason,
            focusNode: _reasonFocus,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) {

              if (_type != null && _type != 'Other' && v.trim() != _type) {
                setState(() => _type = null);
              }
            },
            decoration: InputDecoration(
              hintText: 'Write a short note for the teacher',
              hintStyle: const TextStyle(
                fontSize: 12.5,
                color: ParentColors.muted,
              ),
              filled: true,
              fillColor: ParentColors.pageBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ParentColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ParentColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ParentColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_sending || clash != null) ? null : _send,
              icon: _sending
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.send_rounded, size: 17),
              label: Text(
                _sending ? 'Sending...' : 'Send to teacher',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ParentColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                ParentColors.primary.withValues(alpha: .45),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(_ReasonType t) {
    final on = _type == t.label;
    return GestureDetector(
      onTap: () => _pickType(t),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: on ? ParentColors.primary : ParentColors.tint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on ? ParentColors.primary : ParentColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(t.icon,
                size: 14, color: on ? Colors.white : ParentColors.primary),
            const SizedBox(width: 6),
            Text(
              t.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : ParentColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortcutChip(String label, DateTime from, DateTime to) {
    final on = _from == from && _to == to;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: () => _setRange(from, to),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? ParentColors.dark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: on ? ParentColors.dark : ParentColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : ParentColors.dark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateBox(String label, DateTime d, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ParentColors.pageBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ParentColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded,
                size: 18, color: ParentColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: ParentColors.muted,
                    ),
                  ),
                  Text(
                    AppState.dateLabel(d),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: ParentColors.dark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _durationStrip() {
    final days = _days;
    final weekend = _weekendDays;
    final range = days == 1
        ? AppState.dateLabel(_from)
        : '${AppState.shortDate(_from)} – ${AppState.shortDate(_to)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ParentColors.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded,
              size: 17, color: ParentColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$days day${days == 1 ? '' : 's'} · $range',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark,
                  ),
                ),
                if (weekend > 0)
                  Text(
                    'Includes $weekend weekend day${weekend == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: ParentColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clashNote(LeaveRequest l) {
    final range = l.days <= 1
        ? AppState.shortDate(l.fromDate)
        : '${AppState.shortDate(l.fromDate)} – ${AppState.shortDate(l.toDate)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _pendingBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2D58A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: _pendingFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You already have a ${l.isApproved ? 'approved' : 'pending'} '
                  'leave for $range. Please choose different dates.',
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A5210),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- list ----------
  Widget _filters(int all, int pending, int approved, int declined) {
    Widget chip(String label, int count, String value) {
      final on = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: on ? ParentColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: on ? ParentColors.primary : ParentColors.border,
              ),
            ),
            child: Text(
              '$label · $count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : ParentColors.dark,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', all, 'all'),
          chip('Pending', pending, 'pending'),
          chip('Approved', approved, 'approved'),
          chip('Declined', declined, 'declined'),
        ],
      ),
    );
  }

  Widget _empty(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: _cardDeco,
      child: Column(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 32, color: ParentColors.primaryLight),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: ParentColors.dark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ParentColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveCard(LeaveRequest l) {
    final Color fg;
    final Color bg;
    final String label;
    final IconData icon;
    if (l.isApproved) {
      fg = _approvedFg;
      bg = _approvedBg;
      label = 'Approved';
      icon = Icons.check_circle_rounded;
    } else if (l.isDeclined) {
      fg = _declinedFg;
      bg = _declinedBg;
      label = 'Declined';
      icon = Icons.cancel_rounded;
    } else {
      fg = _pendingFg;
      bg = _pendingBg;
      label = 'Pending';
      icon = Icons.hourglass_top_rounded;
    }

    final range = l.days <= 1
        ? AppState.dateLabel(l.fromDate)
        : '${AppState.shortDate(l.fromDate)} – ${AppState.shortDate(l.toDate)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: _cardDeco,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: fg),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            range,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: ParentColors.dark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 12, color: fg),
                              const SizedBox(width: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.days} day${l.days == 1 ? '' : 's'} · '
                                'Applied ${AppState.shortDate(l.createdAt)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: ParentColors.muted,
                            ),
                          ),
                        ),
                        if (l.isPending)
                          TextButton.icon(
                            onPressed: () => _cancel(l),
                            icon: const Icon(Icons.undo_rounded, size: 14),
                            label: const Text('Withdraw'),
                            style: TextButton.styleFrom(
                              foregroundColor: ParentColors.danger,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l.reason,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: ParentColors.dark,
                      ),
                    ),
                    if (l.teacherNote.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: ParentColors.tint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded,
                                size: 13, color: ParentColors.primary),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Teacher: ${l.teacherNote}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: ParentColors.dark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}