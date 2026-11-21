import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/parent_widgets.dart';
import 'parent_home_screen.dart' show ParentColors;

/// P5 · Fees  (School office कडून येणारा data; सध्या demo)
///
/// Features:
///  - Back arrow (same as Photos / Diary / Circulars)
///  - Hero card: amount due, countdown ("Due in 24 days" / "Overdue"), small How-to-pay card
///  - Summary: Total / Paid / Pending + progress bar
///  - Fee list with status icon, due date and tap-for-details
///  - Receipts list with view / copy
///  - Copy full fee statement
///  - Pull to refresh
class ParentFeesScreen extends StatelessWidget {
  const ParentFeesScreen({super.key, this.onBack});

  /// Back arrow action. By default it goes back to Home
  /// (the shell handles the system back for the tabs).
  final VoidCallback? onBack;

  // ---------- colours for status ----------
  static const _paidFg = Color(0xFF2F8877);
  static const _paidBg = Color(0xFFDDF2EC);
  static const _dueFg = Color(0xFFD9564F);
  static const _dueBg = Color(0xFFFFE7E5);
  static const _upFg = Color(0xFF6B8399);
  static const _upBg = Color(0xFFEFF1F3);

  // ---------- helpers ----------
  String _yearLabel() {
    final now = DateTime.now();
    return now.month >= 4
        ? '${now.year}-${(now.year + 1) % 100}'
        : '${now.year - 1}-${now.year % 100}';
  }

  int _daysLeft(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(d.year, d.month, d.day).difference(today).inDays;
  }

  FeeReceipt? _receiptFor(AppState s, FeeItem f) {
    for (final r in s.receipts) {
      if (f.title.toLowerCase().startsWith(r.title.toLowerCase())) return r;
    }
    return null;
  }

  Future<void> _refresh() =>
      Future<void>.delayed(const Duration(milliseconds: 600));

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final due = s.nextDueFee;

        final total = s.fees.fold<int>(0, (a, f) => a + f.amount);
        final paid = s.fees
            .where((f) => f.status == FeeStatus.paid)
            .fold<int>(0, (a, f) => a + f.amount);
        final pending = total - paid;

        return Column(
          children: [
            _header(context, s, paid, pending, total),
            Expanded(
              child: RefreshIndicator(
                color: ParentColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _hero(context, s, due),
                    const SizedBox(height: 14),
                    _summary(total, paid, pending),
                    const SizedBox(height: 16),
                    _sectionTitle('Fee schedule', 'Year ${_yearLabel()}'),
                    _feeList(context, s),
                    const SizedBox(height: 18),
                    _sectionTitle('Receipts',
                        s.receipts.isEmpty ? null : '${s.receipts.length}'),
                    _receiptList(context, s),
                    const SizedBox(height: 14),
                    _note(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- header (back arrow + title + copy) ----------
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
      BuildContext context, AppState s, int paid, int pending, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          _roundBtn(
            Icons.arrow_back_ios_new_rounded,
            onBack ?? () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fees',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.child.name} · ${s.child.className}',
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
                () => _copyStatement(context, s, paid, pending, total),
            tooltip: 'Copy fee statement',
          ),
        ],
      ),
    );
  }

  Future<void> _copyStatement(BuildContext context, AppState s, int paid,
      int pending, int total) async {
    final b = StringBuffer()
      ..writeln('Fee statement · ${_yearLabel()}')
      ..writeln('Student: ${s.child.name} (${s.child.className})')
      ..writeln();
    for (final f in s.fees) {
      final st = f.status == FeeStatus.paid
          ? 'Paid'
          : f.status == FeeStatus.due
          ? 'Due'
          : 'Upcoming';
      final d = f.dueDate != null && f.status != FeeStatus.paid
          ? ' (by ${AppState.shortDate(f.dueDate!)})'
          : '';
      b.writeln('${f.title}: ${rupees(f.amount)} - $st$d');
    }
    b
      ..writeln()
      ..writeln('Total: ${rupees(total)}')
      ..writeln('Paid: ${rupees(paid)}')
      ..writeln('Pending: ${rupees(pending)}');
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (context.mounted) showSnack(context, 'Fee statement copied');
  }

  // ---------- hero card ----------
  Widget _hero(BuildContext context, AppState s, FeeItem? due) {
    return Container(
      width: double.infinity,
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
      child: due == null ? _heroPaid() : _heroDue(context, s, due),
    );
  }

  Widget _heroPaid() {
    return const Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Color(0x33FFFFFF),
          child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('All fees are paid',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Nothing pending right now. Thank you!',
                  style: TextStyle(color: Color(0xFFEAF5FD), fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroDue(BuildContext context, AppState s, FeeItem due) {
    final days = due.dueDate == null ? null : _daysLeft(due.dueDate!);
    final overdue = days != null && days < 0;
    final countdown = days == null
        ? null
        : overdue
        ? 'Overdue by ${-days} day${-days == 1 ? '' : 's'}'
        : days == 0
        ? 'Due today'
        : 'Due in $days day${days == 1 ? '' : 's'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                due.dueDate == null
                    ? 'Amount due'
                    : 'Due by ${AppState.shortDate(due.dueDate!)}',
                style: const TextStyle(color: Color(0xFFEAF5FD), fontSize: 11.5),
              ),
            ),
            if (countdown != null)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: overdue ? ParentColors.danger : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  countdown,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          rupees(due.amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${due.title} · ${s.child.name}',
          style: const TextStyle(color: Color(0xFFEAF5FD), fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        // Small "How to pay" card
        Material(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _howToPay(context, s, due),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x40FFFFFF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_rounded,
                        size: 15, color: ParentColors.primary),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('How to pay',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                        Text('School office · Cash / UPI',
                            style: TextStyle(
                                color: Color(0xFFEAF5FD), fontSize: 10)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- summary ----------
  Widget _summary(int total, int paid, int pending) {
    final progress = total == 0 ? 0.0 : paid / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            children: [
              _stat('Total', rupees(total), ParentColors.dark),
              _divider(),
              _stat('Paid', rupees(paid), _paidFg),
              _divider(),
              _stat('Pending', rupees(pending),
                  pending == 0 ? _paidFg : _dueFg),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: ParentColors.tintStrong,
              valueColor: const AlwaysStoppedAnimation(ParentColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${(progress * 100).round()}% of the yearly fees paid',
              style: const TextStyle(
                  fontSize: 11,
                  color: ParentColors.muted,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: ParentColors.muted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: ParentColors.border);

  // ---------- fee list ----------
  Widget _feeList(BuildContext context, AppState s) {
    return Container(
      decoration: _cardDeco(),
      child: Column(
        children: [
          for (var i = 0; i < s.fees.length; i++) ...[
            _feeRow(context, s, s.fees[i]),
            if (i != s.fees.length - 1)
              const Divider(height: 1, indent: 64, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _feeRow(BuildContext context, AppState s, FeeItem f) {
    final IconData icon;
    final Color fg;
    final Color bg;
    final String chip;
    switch (f.status) {
      case FeeStatus.paid:
        icon = Icons.check_circle_rounded;
        fg = _paidFg;
        bg = _paidBg;
        chip = 'Paid';
        break;
      case FeeStatus.due:
        icon = Icons.error_outline_rounded;
        fg = _dueFg;
        bg = _dueBg;
        chip = 'Due';
        break;
      case FeeStatus.upcoming:
        icon = Icons.schedule_rounded;
        fg = _upFg;
        bg = _upBg;
        chip = 'Upcoming';
        break;
    }

    final receipt = _receiptFor(s, f);
    final sub = f.status == FeeStatus.paid
        ? (receipt == null
        ? rupees(f.amount)
        : '${rupees(f.amount)} · Paid ${AppState.shortDate(receipt.date)}')
        : (f.dueDate == null
        ? rupees(f.amount)
        : '${rupees(f.amount)} · Due by ${AppState.shortDate(f.dueDate!)}');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _feeDetail(context, s, f, receipt),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.title,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.dark)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: ParentColors.muted,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            StatusChip(chip, bg: bg, fg: fg),
          ],
        ),
      ),
    );
  }

  void _feeDetail(
      BuildContext context, AppState s, FeeItem f, FeeReceipt? receipt) {
    final statusText = f.status == FeeStatus.paid
        ? 'Paid'
        : f.status == FeeStatus.due
        ? 'Due'
        : 'Upcoming';
    final color = f.status == FeeStatus.paid
        ? _paidFg
        : f.status == FeeStatus.due
        ? _dueFg
        : _upFg;

    _sheet(
      context,
      title: f.title,
      amount: rupees(f.amount),
      amountColor: color,
      rows: [
        _row('Student', s.child.name),
        _row('Class', s.child.className),
        _row('Status', statusText),
        if (f.dueDate != null && f.status != FeeStatus.paid)
          _row('Due date', AppState.dateLabel(f.dueDate!)),
        if (receipt != null) ...[
          _row('Paid on', AppState.dateLabel(receipt.date)),
          _row('Mode', receipt.mode),
        ],
      ],
      copyText: '${f.title} · ${rupees(f.amount)} · $statusText\n'
          'Student: ${s.child.name} (${s.child.className})',
      footer: receipt != null
          ? null
          : f.status == FeeStatus.paid
          ? null
          : const Text(
        'Please pay at the school office. Online payment will be added later.',
        style: TextStyle(fontSize: 12, color: ParentColors.muted),
      ),
    );
  }

  // ---------- receipts ----------
  Widget _receiptList(BuildContext context, AppState s) {
    if (s.receipts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        decoration: _cardDeco(),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 34, color: ParentColors.muted),
            SizedBox(height: 8),
            Text('No receipts yet',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark)),
            SizedBox(height: 2),
            Text('Receipts appear here once a payment is recorded.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: ParentColors.muted)),
          ],
        ),
      );
    }

    return Container(
      decoration: _cardDeco(),
      child: Column(
        children: [
          for (var i = 0; i < s.receipts.length; i++) ...[
            _receiptRow(context, s, s.receipts[i]),
            if (i != s.receipts.length - 1)
              const Divider(height: 1, indent: 64, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _receiptRow(BuildContext context, AppState s, FeeReceipt r) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _receipt(context, s, r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ParentColors.tintStrong,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 20, color: ParentColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.title} receipt',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.dark)),
                  const SizedBox(height: 2),
                  Text('${AppState.shortDate(r.date)} · ${r.mode}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: ParentColors.muted,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(rupees(r.amount),
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: ParentColors.dark)),
                const SizedBox(height: 2),
                const Text('View',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ParentColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _receipt(BuildContext context, AppState s, FeeReceipt r) {
    _sheet(
      context,
      title: 'Fee receipt',
      amount: rupees(r.amount),
      amountColor: _paidFg,
      badge: const StatusChip('Paid', bg: _paidBg, fg: _paidFg),
      rows: [
        _row('Student', s.child.name),
        _row('Class', s.child.className),
        _row('Fee', r.title),
        _row('Paid on', AppState.dateLabel(r.date)),
        _row('Mode', r.mode),
      ],
      copyText: 'Fee receipt\n'
          'Student: ${s.child.name}\n'
          'Class: ${s.child.className}\n'
          'Fee: ${r.title}\n'
          'Amount: ${rupees(r.amount)}\n'
          'Paid on: ${AppState.shortDate(r.date)}\n'
          'Mode: ${r.mode}',
    );
  }

  // ---------- how to pay ----------
  void _howToPay(BuildContext context, AppState s, FeeItem due) {
    _sheet(
      context,
      title: 'How to pay',
      amount: rupees(due.amount),
      amountColor: _dueFg,
      rows: [
        _row('Fee', due.title),
        _row('Student', s.child.name),
        if (due.dueDate != null)
          _row('Last date', AppState.dateLabel(due.dueDate!)),
        _row('Pay at', 'School office'),
        _row('Accepted', 'Cash / UPI'),
      ],
      copyText: '${due.title} · ${rupees(due.amount)}\n'
          'Student: ${s.child.name} (${s.child.className})',
      footer: const Text(
        'Online payment will be added later. Please carry this screen '
            'or the child\'s name when you visit the office.',
        style: TextStyle(fontSize: 12, color: ParentColors.muted, height: 1.5),
      ),
    );
  }

  // ---------- shared bottom sheet ----------
  void _sheet(
      BuildContext context, {
        required String title,
        required String amount,
        required Color amountColor,
        required List<Widget> rows,
        required String copyText,
        Widget? badge,
        Widget? footer,
      }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: ParentColors.dark)),
                  ),
                  if (badge != null) badge,
                ],
              ),
              const SizedBox(height: 6),
              Text(amount,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: amountColor)),
              const SizedBox(height: 14),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: rows),
              ),
              if (footer != null) ...[
                const SizedBox(height: 12),
                footer,
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: copyText));
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          showSnack(context, 'Copied');
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: ParentColors.muted,
                    fontWeight: FontWeight.w600)),
          ),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    color: ParentColors.dark,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ---------- small pieces ----------
  Widget _sectionTitle(String title, String? trailing) {
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
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ParentColors.muted)),
        ],
      ),
    );
  }

  Widget _note() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: ParentColors.muted),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Fee details are entered by the school office. '
                  'Online payment can be added later.',
              style: TextStyle(
                  fontSize: 11, color: ParentColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
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