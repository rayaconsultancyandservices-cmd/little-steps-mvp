import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Fees: fee जोडा (एका मुलाला / पूर्ण class ला), paid mark करा – Parent app ला लगेच दिसतं.
class AdminFeesScreen extends StatefulWidget {
  const AdminFeesScreen({super.key});

  @override
  State<AdminFeesScreen> createState() => _AdminFeesScreenState();
}

class _AdminFeesScreenState extends State<AdminFeesScreen> {
  static const _modes = ['Cash', 'UPI', 'Card', 'Bank transfer', 'Cheque'];

  final _search = TextEditingController();
  String _q = '';
  int _statusFilter = 0; // 0 all, 1 due, 2 paid, 3 upcoming

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addFee() async {
    final s = AdminState.instance;
    if (s.students.isEmpty) {
      adminSnack(context, 'Add students first.', error: true);
      return;
    }
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final amount = TextEditingController();
    String? classId = s.classes.isNotEmpty ? s.classes.first.id : null;
    String? studentId; // null = वर्गातले सर्व
    DateTime? due;
    bool upcoming = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final inClass = classId == null
              ? <ChildInfo>[]
              : s.studentsOfClass(classId!);
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text('Add fee'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      dialogField(title, 'Fee title',
                          required: true, hint: 'e.g. Term 2 Tuition Fee'),
                      dialogField(
                        amount,
                        'Amount (₹)',
                        keyboard: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return (n == null || n <= 0) ? 'Enter amount' : null;
                        },
                      ),
                      AdminDropdown<String>(
                        label: 'Class',
                        width: 440,
                        value: classId,
                        items: [
                          for (final c in s.classes)
                            DropdownMenuItem(value: c.id, child: Text(c.className)),
                        ],
                        onChanged: (v) => setD(() {
                          classId = v;
                          studentId = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      AdminDropdown<String?>(
                        label: 'Student',
                        width: 440,
                        value: studentId,
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All students (${inClass.length})'),
                          ),
                          for (final c in inClass)
                            DropdownMenuItem<String?>(
                                value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setD(() => studentId = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: due ?? now,
                                firstDate: DateTime(now.year - 1),
                                lastDate: DateTime(now.year + 2),
                              );
                              if (d != null) setD(() => due = d);
                            },
                            icon: const Icon(Icons.event_rounded, size: 18),
                            label: Text(due == null ? 'Due date' : fmtDate(due)),
                          ),
                          const Spacer(),
                          const Text('Upcoming', style: TextStyle(fontSize: 12)),
                          Switch(
                            value: upcoming,
                            onChanged: (v) => setD(() => upcoming = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: adminPrimaryButton(),
                onPressed: () {
                  if (formKey.currentState!.validate() && classId != null) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Add fee'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || classId == null) return;
    final ids = studentId != null
        ? [studentId!]
        : s.studentsOfClass(classId!).map((c) => c.id).toList();
    if (ids.isEmpty) {
      if (mounted) adminSnack(context, 'No students in this class.', error: true);
      return;
    }
    try {
      await s.addFee(ids, title.text, int.parse(amount.text.trim()), due,
          upcoming: upcoming);
      if (mounted) adminSnack(context, 'Fee added for ${ids.length} student(s)');
    } catch (e) {
      if (mounted) adminSnack(context, '$e', error: true);
    }
  }

  Future<void> _markPaid(AdminFee f) async {
    String mode = _modes.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Mark as paid'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${f.title} · ${fmtMoney(f.amount)}\n'
                      '${AdminState.instance.studentName(f.studentId)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                AdminDropdown<String>(
                  label: 'Payment mode',
                  width: 360,
                  value: mode,
                  items: [
                    for (final m in _modes)
                      DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => setD(() => mode = v ?? mode),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: adminPrimaryButton(),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark paid'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await AdminState.instance.markFeePaid(f, mode);
      if (mounted) adminSnack(context, 'Marked as paid · receipt created');
    } catch (e) {
      if (mounted) adminSnack(context, '$e', error: true);
    }
  }

  Future<void> _delete(AdminFee f) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete this fee?',
      message: '${f.title} (${fmtMoney(f.amount)}) will be removed for '
          '${AdminState.instance.studentName(f.studentId)}.',
    );
    if (!ok) return;
    try {
      await AdminState.instance.deleteFee(f);
    } catch (e) {
      if (mounted) adminSnack(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final list = s.fees.where((f) {
          if (_statusFilter == 1 && f.status != FeeStatus.due) return false;
          if (_statusFilter == 2 && f.status != FeeStatus.paid) return false;
          if (_statusFilter == 3 && f.status != FeeStatus.upcoming) return false;
          if (_q.isEmpty) return true;
          return '${s.studentName(f.studentId)} ${f.title}'
              .toLowerCase()
              .contains(_q);
        }).toList();

        return AdminPage(
          title: 'Fees',
          subtitle: 'Fees added here appear instantly in the Parent app',
          actions: [
            AdminSearchField(
              controller: _search,
              hint: 'Search student or fee…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            FilledButton.icon(
              style: adminPrimaryButton(),
              onPressed: _addFee,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add fee'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorBanner(s.lastError),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  StatCard(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Collected',
                    value: fmtMoney(s.collectedFeesTotal),
                    color: AdminColors.green,
                  ),
                  StatCard(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending',
                    value: fmtMoney(s.pendingFeesTotal),
                    note: '${s.studentsWithDues} students',
                    color: AdminColors.red,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('All')),
                  ButtonSegment(value: 1, label: Text('Due')),
                  ButtonSegment(value: 2, label: Text('Paid')),
                  ButtonSegment(value: 3, label: Text('Upcoming')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (v) => setState(() => _statusFilter = v.first),
              ),
              const SizedBox(height: 16),
              AdminCard(
                child: AdminTable(
                  emptyText: 'No fees yet. Use "Add fee" to create one.',
                  columns: const [
                    'Student',
                    'Class',
                    'Fee',
                    'Amount',
                    'Due date',
                    'Status',
                    '',
                  ],
                  rows: [
                    for (final f in list)
                      DataRow(cells: [
                        cellText(s.studentName(f.studentId), bold: true),
                        cellText(s.studentById(f.studentId)?.className ?? ''),
                        cellText(f.title),
                        cellText(fmtMoney(f.amount), bold: true),
                        cellText(fmtDate(f.dueDate)),
                        DataCell(_status(f.status)),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (f.status != FeeStatus.paid)
                              TextButton(
                                onPressed: () => _markPaid(f),
                                child: const Text('Mark paid'),
                              ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 19, color: AdminColors.red),
                              onPressed: () => _delete(f),
                            ),
                          ],
                        )),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _status(FeeStatus st) {
    switch (st) {
      case FeeStatus.paid:
        return const StatusChip('Paid', AdminColors.green);
      case FeeStatus.due:
        return const StatusChip('Due', AdminColors.red);
      case FeeStatus.upcoming:
        return const StatusChip('Upcoming', AdminColors.blue);
    }
  }
}