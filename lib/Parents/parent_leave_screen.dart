import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'parent_home_screen.dart' show ParentColors;

/// Parent · Leave application (रजेचा अर्ज)
///
///  - Back arrow (same as the other Parent screens)
///  - Form: from date, to date, reason (+ quick reason chips), Send
///  - "My applications": status chip (Pending / Approved / Declined),
///    Teacher ची note, pending अर्ज मागे घेण्याचं बटण
/// अर्ज Firestore मार्फत Teacher च्या Leave screen मध्ये लगेच दिसतो.
class ParentLeaveScreen extends StatefulWidget {
  const ParentLeaveScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ParentLeaveScreen> createState() => _ParentLeaveScreenState();
}

class _ParentLeaveScreenState extends State<ParentLeaveScreen> {
  static const List<String> _quickReasons = [
    'Fever / not well',
    'Family function',
    'Out of station',
    'Other',
  ];

  final TextEditingController _reason = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _from = DateTime(n.year, n.month, n.day);
    _to = _from;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: isFrom ? first : _from,
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

  Future<void> _send() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      _snack('Please write the reason for leave.');
      return;
    }
    setState(() => _sending = true);
    try {
      await AppState.instance.submitLeave(from: _from, to: _to, reason: reason);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _reason.clear();
        final n = DateTime.now();
        _from = DateTime(n.year, n.month, n.day);
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
    return Scaffold(
      backgroundColor: ParentColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: AnimatedBuilder(
                animation: AppState.instance,
                builder: (context, _) {
                  final list = AppState.instance.leaves;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _formCard(),
                      const SizedBox(height: 18),
                      const Text(
                        'My applications',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: ParentColors.dark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (list.isEmpty)
                        _empty()
                      else
                        for (final l in list) _leaveCard(l),
                    ],
                  );
                },
              ),
            ),
          ],
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

  // ---------- form ----------
  BoxDecoration get _cardDeco => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: ParentColors.border),
  );

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _dateBox('From', _from, () => _pickDate(isFrom: true))),
              const SizedBox(width: 10),
              Expanded(child: _dateBox('To', _to, () => _pickDate(isFrom: false))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final r in _quickReasons)
                ActionChip(
                  label: Text(r, style: const TextStyle(fontSize: 11)),
                  backgroundColor: ParentColors.tint,
                  side: BorderSide.none,
                  onPressed: () => setState(() {
                    _reason.text = r == 'Other' ? '' : r;
                    _reason.selection = TextSelection.collapsed(
                      offset: _reason.text.length,
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Reason for leave',
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
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded, size: 17),
              label: Text(
                _sending ? 'Please wait...' : 'Send to teacher',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ParentColors.primary,
                foregroundColor: Colors.white,
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

  // ---------- list ----------
  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: _cardDeco,
      child: const Column(
        children: [
          Icon(Icons.event_available_rounded,
              size: 30, color: ParentColors.primaryLight),
          SizedBox(height: 8),
          Text(
            'No leave applications yet',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ParentColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveCard(LeaveRequest l) {
    final Color color;
    final String label;
    if (l.isApproved) {
      color = const Color(0xFF2E9E7B);
      label = 'Approved';
    } else if (l.isDeclined) {
      color = ParentColors.danger;
      label = 'Declined';
    } else {
      color = const Color(0xFFE59A2E);
      label = 'Pending';
    }

    final range = l.days <= 1
        ? AppState.dateLabel(l.fromDate)
        : '${AppState.shortDate(l.fromDate)} – ${AppState.shortDate(l.toDate)}'
        ' · ${l.days} days';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: _cardDeco,
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
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.reason,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: ParentColors.muted,
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
              child: Text(
                'Teacher: ${l.teacherNote}',
                style: const TextStyle(
                  fontSize: 11,

                  fontWeight: FontWeight.w600,
                  color: ParentColors.dark,
                ),
              ),
            ),
          ],
          if (l.isPending) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _cancel(l),
                icon: const Icon(Icons.undo_rounded, size: 15),
                label: const Text('Withdraw'),
                style: TextButton.styleFrom(
                  foregroundColor: ParentColors.danger,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}