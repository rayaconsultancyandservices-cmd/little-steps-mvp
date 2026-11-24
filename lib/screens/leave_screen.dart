import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/page_app_bar.dart';

/// Teacher · Leave requests (रजेचे अर्ज)
///
///  - Parent ने पाठवलेले अर्ज लगेच दिसतात (Pending आधी)
///  - Filter: Pending / All
///  - Approve / Decline + पर्यायी note (Parent ला दिसते)
///  - निर्णय दिलेला अर्ज परत बदलता येतो (Change)
class TeacherLeaveScreen extends StatefulWidget {
  const TeacherLeaveScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends State<TeacherLeaveScreen> {
  static const Color _dark = Color(0xFF24313D);
  static const Color _muted = Color(0xFF7B8794);
  static const Color _danger = Color(0xFFE5484D);
  static const Color _ok = Color(0xFF2E9E7B);
  static const Color _warn = Color(0xFFE59A2E);

  bool _pendingOnly = true;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _decide(LeaveRequest l, bool approve) async {
    final note = TextEditingController(text: l.teacherNote);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          approve ? 'Approve leave?' : 'Decline leave?',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: note,
          maxLength: 200,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Note for parent (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: approve ? _ok : _danger,
            ),
            child: Text(approve ? 'Approve' : 'Decline'),
          ),
        ],
      ),
    );
    final text = note.text;
    note.dispose();
    if (ok != true) return;

    try {
      await AppState.instance.decideLeave(l.id, approved: approve, note: text);
      if (!mounted) return;
      _snack(approve ? 'Leave approved.' : 'Leave declined.');
    } catch (_) {
      if (!mounted) return;
      _snack('Could not save. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: buildPageAppBar(
        title: 'Leave Requests',
        subtitle: AppState.instance.className,
        onBack: widget.onBack,
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final all = AppState.instance.leaves;
          final pending = all.where((l) => l.isPending).toList();
          final shown = _pendingOnly ? pending : all;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  _chip('Pending (${pending.length})', _pendingOnly, true),
                  const SizedBox(width: 8),
                  _chip('All (${all.length})', !_pendingOnly, false),
                ],
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                _empty()
              else
                for (final l in shown) _card(l),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, bool pendingValue) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: selected,
      selectedColor: AppColors.primaryLight,
      backgroundColor: Colors.white,
      onSelected: (_) => setState(() => _pendingOnly = pendingValue),
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECE9)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 34, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            _pendingOnly ? 'No pending leave requests' : 'No leave requests yet',
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(LeaveRequest l) {
    final Color color;
    final String label;
    if (l.isApproved) {
      color = _ok;
      label = 'Approved';
    } else if (l.isDeclined) {
      color = _danger;
      label = 'Declined';
    } else {
      color = _warn;
      label = 'Pending';
    }

    final range = l.days <= 1
        ? AppState.dateLabel(l.fromDate)
        : '${AppState.shortDate(l.fromDate)} – ${AppState.shortDate(l.toDate)}'
        ' · ${l.days} days';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE7EEEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            range,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.reason,
            style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
          ),
          if (l.parentName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Parent: ${l.parentName} · '
                  '${AppState.relativeDay(l.createdAt)}',
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ],
          if (l.teacherNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Your note: ${l.teacherNote}',
              style: const TextStyle(
                color: _dark,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (l.isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(l, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _danger,
                      side: const BorderSide(color: _danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decide(l, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _decide(l, !l.isApproved),
                child: Text(
                  l.isApproved ? 'Change to Declined' : 'Change to Approved',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}