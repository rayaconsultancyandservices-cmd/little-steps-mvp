import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Fees: fee जोडा (एका मुलाला / पूर्ण class ला), paid mark करा – Parent app ला लगेच दिसतं.
///
/// NEW (Payment requests):
///  - Parent ने UPI ने भरून पाठवलेल्या सर्व classes च्या requests (UTR सह) नवीन "Requests" tab मध्ये
///  - Verify -> fee paid + receipt (feeId + UTR सहित) + request verified (एकाच batch मध्ये)
///  - Reject -> कारण (पर्यायी) Parent ला दिसतं
///  - वर "To verify" card; "Mark paid" केल्यावर त्या fee ची submitted request आपोआप verified
///  - Admin च्या receipts मध्ये आता feeId जातो (आधी नव्हता, म्हणून Parent/Teacher ला जुळत नव्हता)
///  - NEW: paid fee साठी "Mark unpaid" (receipt सुद्धा काढतो); fee delete केल्यावर तिचे receipts सुद्धा जातात
/// 3:07 PM
String _time(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

/// Parent ची payment request  (students/{studentId}/payments/{id})
class _AdminClaim {
  const _AdminClaim({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.feeId,
    required this.title,
    required this.amount,
    required this.utr,
    required this.status,
    required this.createdAt,
    this.note = '',
    this.reviewedBy = '',
  });

  final String id;
  final String studentId;
  final String classId;
  final String feeId;
  final String title;
  final int amount;
  final String utr;

  /// submitted | verified | rejected
  final String status;
  final DateTime createdAt;
  final String note;
  final String reviewedBy;

  bool get isSubmitted => status == 'submitted';

  factory _AdminClaim.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    final ts = x['createdAt'];
    final amt = x['amount'];
    return _AdminClaim(
      id: d.id,
      // path: students/{studentId}/payments/{id}
      studentId: d.reference.parent.parent?.id ?? '',
      classId: (x['classId'] ?? '').toString(),
      feeId: (x['feeId'] ?? '').toString(),
      title: (x['title'] ?? '').toString(),
      amount: amt is num ? amt.toInt() : 0,
      utr: (x['utr'] ?? '').toString(),
      status: (x['status'] ?? 'submitted').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      note: (x['note'] ?? '').toString(),
      reviewedBy: (x['reviewedBy'] ?? '').toString(),
    );
  }
}

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
  int _tab = 0; // 0 fees, 1 receipts
  String? _classFilter;

  // Payment requests (सर्व classes) - collectionGroup('payments')
  int _reqFilter = 0; // 0 waiting, 1 verified, 2 rejected, 3 all
  List<_AdminClaim> _claims = [];
  String? _claimsError;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _claimsSub;

  @override
  void initState() {
    super.initState();
    _claimsSub = FirebaseFirestore.instance
        .collectionGroup('payments')
        .snapshots()
        .listen(
          (snap) {
        if (!mounted) return;
        setState(() {
          _claims = [for (final d in snap.docs) _AdminClaim.fromDoc(d)]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _claimsError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _claimsError =
        'Payment requests could not be loaded. '
            'Please publish the latest Firestore rules.');
      },
    );
  }

  @override
  void dispose() {
    _claimsSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  String get _reviewer => FirebaseAuth.instance.currentUser?.email ?? 'Admin';

  /// या fee साठी Parent ची "submitted" requests.
  List<_AdminClaim> _waitingFor(AdminFee f) => [
    for (final c in _claims)
      if (c.isSubmitted && c.studentId == f.studentId && c.feeId == f.id) c,
  ];

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
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _editFee(AdminFee f) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(text: f.title);
    final amount = TextEditingController(text: '${f.amount}');
    DateTime? due = f.dueDate;
    bool upcoming = f.status == FeeStatus.upcoming;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text('Edit fee · ${AdminState.instance.studentName(f.studentId)}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    dialogField(title, 'Fee title', required: true),
                    dialogField(
                      amount,
                      'Amount (₹)',
                      keyboard: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        return (n == null || n <= 0) ? 'Enter amount' : null;
                      },
                    ),
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
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await AdminState.instance.updateFee(
        f,
        title: title.text,
        amount: int.parse(amount.text.trim()),
        dueDate: due,
        upcoming: upcoming,
      );
      if (mounted) adminSnack(context, 'Fee updated');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _markPaid(AdminFee f) async {
    final waiting = _waitingFor(f);
    String mode = waiting.isNotEmpty ? 'UPI' : _modes.first;
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
      final db = FirebaseFirestore.instance;
      final sRef = db.collection('students').doc(f.studentId);
      final batch = db.batch();
      batch.update(sRef.collection('fees').doc(f.id), {'status': 'paid'});
      batch.set(sRef.collection('receipts').doc(), {
        'title': f.title,
        'amount': f.amount,
        'date': Timestamp.now(),
        'mode': mode,
        'feeId': f.id,
      });
      // या fee ची Parent ची submitted request असेल तर तीही verified.
      for (final c in waiting) {
        batch.update(sRef.collection('payments').doc(c.id), {
          'status': 'verified',
          'reviewedAt': Timestamp.now(),
          'reviewedBy': _reviewer,
        });
      }
      await batch.commit();
      if (mounted) adminSnack(context, 'Marked as paid · receipt created');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _delete(AdminFee f) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete this fee?',
      message: '${f.title} (${fmtMoney(f.amount)}) will be removed for '
          '${AdminState.instance.studentName(f.studentId)}'
          '${f.status == FeeStatus.paid ? ', along with its receipt' : ''}.',
    );
    if (!ok) return;
    try {
      final sRef =
      FirebaseFirestore.instance.collection('students').doc(f.studentId);
      final rec =
      await sRef.collection('receipts').where('feeId', isEqualTo: f.id).get();
      final batch = FirebaseFirestore.instance.batch();
      for (final d in rec.docs) {
        batch.delete(d.reference);
      }
      batch.delete(sRef.collection('fees').doc(f.id));
      await batch.commit();
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _markUnpaid(AdminFee f) async {
    final ok = await adminConfirm(
      context,
      title: 'Mark as unpaid?',
      message: '${f.title} (${fmtMoney(f.amount)}) will go back to pending and '
          'its receipt will be removed for '
          '${AdminState.instance.studentName(f.studentId)}.',
      confirmText: 'Mark unpaid',
      danger: false,
    );
    if (!ok || !mounted) return;
    try {
      final sRef =
      FirebaseFirestore.instance.collection('students').doc(f.studentId);
      final rec =
      await sRef.collection('receipts').where('feeId', isEqualTo: f.id).get();
      final batch = FirebaseFirestore.instance.batch();
      for (final d in rec.docs) {
        batch.delete(d.reference);
      }
      batch.update(sRef.collection('fees').doc(f.id), {'status': 'due'});
      await batch.commit();
      if (mounted) adminSnack(context, 'Marked as unpaid · receipt removed');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  /// Parent ची payment request verify: fee paid + receipt (UTR सह) + request verified.
  Future<void> _verifyClaim(_AdminClaim c) async {
    final matches = AdminState.instance.fees
        .where((f) => c.feeId.isNotEmpty && f.id == c.feeId && f.studentId == c.studentId);
    if (matches.isEmpty) {
      adminSnack(
        context,
        'The fee for this request no longer exists. You can reject the request.',
        error: true,
      );
      return;
    }
    final fee = matches.first;
    final already = fee.status == FeeStatus.paid;
    final differs = fee.amount != c.amount;

    final ok = await adminConfirm(
      context,
      title: 'Verify payment?',
      confirmText: 'Verify',
      danger: false,
      message: '${AdminState.instance.studentName(c.studentId)} · ${fee.title}\n'
          'Amount: ${fmtMoney(fee.amount)}   UTR: ${c.utr}\n\n'
          '${already ? 'This fee is already marked paid. The request will just be marked verified.' : 'The fee will be marked paid and a receipt (mode UPI) will be created for the parent.'}'
          '${differs ? '\n\nNote: the parent paid ${fmtMoney(c.amount)}, but the fee is now ${fmtMoney(fee.amount)}. Check your bank before verifying.' : ''}'
          '\n\nVerify only after you see this UTR in your bank / UPI app.',
    );
    if (!ok || !mounted) return;

    try {
      final db = FirebaseFirestore.instance;
      final sRef = db.collection('students').doc(c.studentId);
      final batch = db.batch();
      if (!already) {
        batch.update(sRef.collection('fees').doc(fee.id), {'status': 'paid'});
        batch.set(sRef.collection('receipts').doc(), {
          'title': fee.title,
          'amount': fee.amount,
          'date': Timestamp.now(),
          'mode': 'UPI',
          'feeId': fee.id,
          'utr': c.utr,
        });
      }
      batch.update(sRef.collection('payments').doc(c.id), {
        'status': 'verified',
        'reviewedAt': Timestamp.now(),
        'reviewedBy': _reviewer,
      });
      await batch.commit();
      if (mounted) {
        adminSnack(
          context,
          already
              ? 'Request marked as verified'
              : 'Payment verified · fee marked paid · receipt created',
        );
      }
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  /// Parent ची payment request reject (कारण पर्यायी, Parent ला दिसतं).
  Future<void> _rejectClaim(_AdminClaim c) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Reject payment request?'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AdminState.instance.studentName(c.studentId)} · '
                    '${c.title.isEmpty ? 'Fee payment' : c.title} · ${fmtMoney(c.amount)}\n'
                    'UTR: ${c.utr}',
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5),
              ),
              const SizedBox(height: 14),
              dialogField(
                note,
                'Reason for parent (optional)',
                hint: 'e.g. UTR not found in bank',
                maxLines: 2,
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
            style: adminDangerButton(),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(c.studentId)
          .collection('payments')
          .doc(c.id)
          .update({
        'status': 'rejected',
        'note': note.text.trim(),
        'reviewedAt': Timestamp.now(),
        'reviewedBy': _reviewer,
      });
      if (mounted) adminSnack(context, 'Request rejected · the parent can see your note');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final list = s.fees.where((f) {
          if (_classFilter != null &&
              s.studentById(f.studentId)?.classId != _classFilter) {
            return false;
          }
          if (_statusFilter == 1 && f.status != FeeStatus.due) return false;
          if (_statusFilter == 2 && f.status != FeeStatus.paid) return false;
          if (_statusFilter == 3 && f.status != FeeStatus.upcoming) return false;
          if (_q.isEmpty) return true;
          return '${s.studentName(f.studentId)} ${f.title}'
              .toLowerCase()
              .contains(_q);
        }).toList();

        final receiptList = s.receipts.where((r) {
          if (_classFilter != null &&
              s.studentById(r.studentId)?.classId != _classFilter) {
            return false;
          }
          if (_q.isEmpty) return true;
          return '${s.studentName(r.studentId)} ${r.title} ${r.mode}'
              .toLowerCase()
              .contains(_q);
        }).toList();

        final waitingCount = _claims.where((c) => c.isSubmitted).length;
        final claimList = _claims.where((c) {
          final cls = s.studentById(c.studentId)?.classId ?? c.classId;
          if (_classFilter != null && cls != _classFilter) return false;
          if (_reqFilter == 0 && c.status != 'submitted') return false;
          if (_reqFilter == 1 && c.status != 'verified') return false;
          if (_reqFilter == 2 && c.status != 'rejected') return false;
          if (_q.isEmpty) return true;
          return '${s.studentName(c.studentId)} ${c.title} ${c.utr}'
              .toLowerCase()
              .contains(_q);
        }).toList();

        return AdminPage(
          title: 'Fees',
          subtitle: 'Fees added here appear instantly in the Parent app',
          actions: [
            AdminSearchField(
              controller: _search,
              hint: 'Search student, fee or UTR…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            AdminDropdown<String?>(
              label: 'Class',
              width: 190,
              value: _classFilter,
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All classes')),
                for (final c in s.classes)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.className)),
              ],
              onChanged: (v) => setState(() => _classFilter = v),
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
              ErrorBanner(s.lastError ?? _claimsError),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cardWidth = width >= 1400
                      ? (width - 64) / 5
                      : width >= 1100
                      ? (width - 48) / 4
                      : width >= 650
                      ? (width - 16) / 2
                      : width;
                  final dueCount = s.fees.where((f) => f.status == FeeStatus.due).length;
                  final paidCount = s.fees.where((f) => f.status == FeeStatus.paid).length;
                  final upcomingCount = s.fees.where((f) => f.status == FeeStatus.upcoming).length;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _FeeMetricCard(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Collected',
                          value: fmtMoney(s.collectedFeesTotal),
                          note: '$paidCount paid records',
                          color: AdminColors.green,
                          selected: _statusFilter == 2 && _tab == 0,
                          onTap: () => setState(() { _tab = 0; _statusFilter = 2; }),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FeeMetricCard(
                          icon: Icons.pending_actions_rounded,
                          label: 'Pending',
                          value: fmtMoney(s.pendingFeesTotal),
                          note: '${s.studentsWithDues} students with dues',
                          color: AdminColors.red,
                          selected: _statusFilter == 1 && _tab == 0,
                          onTap: () => setState(() { _tab = 0; _statusFilter = 1; }),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FeeMetricCard(
                          icon: Icons.receipt_long_rounded,
                          label: 'Due fees',
                          value: '$dueCount',
                          note: 'Awaiting payment',
                          color: AdminColors.orange,
                          selected: _statusFilter == 1 && _tab == 0,
                          onTap: () => setState(() { _tab = 0; _statusFilter = 1; }),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FeeMetricCard(
                          icon: Icons.event_available_rounded,
                          label: 'Upcoming',
                          value: '$upcomingCount',
                          note: 'Scheduled fees',
                          color: AdminColors.blue,
                          selected: _statusFilter == 3 && _tab == 0,
                          onTap: () => setState(() { _tab = 0; _statusFilter = 3; }),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FeeMetricCard(
                          icon: Icons.fact_check_rounded,
                          label: 'To verify',
                          value: '$waitingCount',
                          note: 'Parent payment requests',
                          color: AdminColors.purple,
                          selected: _tab == 2,
                          onTap: () => setState(() { _tab = 2; _reqFilter = 0; }),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(value: 0, label: Text('Fees')),
                  const ButtonSegment(value: 1, label: Text('Receipts')),
                  ButtonSegment(
                    value: 2,
                    label: Text(waitingCount > 0
                        ? 'Requests ($waitingCount)'
                        : 'Requests'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (v) => setState(() => _tab = v.first),
              ),
              const SizedBox(height: 12),
              if (_tab == 2) ...[
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(waitingCount > 0
                          ? 'Waiting ($waitingCount)'
                          : 'Waiting'),
                    ),
                    const ButtonSegment(value: 1, label: Text('Verified')),
                    const ButtonSegment(value: 2, label: Text('Rejected')),
                    const ButtonSegment(value: 3, label: Text('All')),
                  ],
                  selected: {_reqFilter},
                  onSelectionChanged: (v) => setState(() => _reqFilter = v.first),
                ),
                const SizedBox(height: 16),
                AdminCard(
                  title: 'Payment requests (${claimList.length})',
                  child: AdminTable(
                    emptyText: _reqFilter == 0
                        ? 'No payment requests are waiting for verification.'
                        : 'No payment requests here.',
                    columns: const [
                      'Sent',
                      'Student',
                      'Class',
                      'Fee',
                      'Amount',
                      'UTR',
                      'Status',
                      'Note',
                      '',
                    ],
                    rows: [
                      for (final c in claimList)
                        DataRow(cells: [
                          cellText('${fmtDate(c.createdAt)}, ${_time(c.createdAt)}'),
                          cellText(s.studentName(c.studentId), bold: true),
                          cellText(s.studentById(c.studentId)?.className ?? ''),
                          cellText(c.title),
                          cellText(fmtMoney(c.amount), bold: true),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(c.utr,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700)),
                              IconButton(
                                tooltip: 'Copy UTR',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: c.utr));
                                  if (mounted) adminSnack(context, 'UTR copied');
                                },
                              ),
                            ],
                          )),
                          DataCell(c.isSubmitted
                              ? const StatusChip('Waiting', AdminColors.orange)
                              : c.status == 'verified'
                              ? const StatusChip('Verified', AdminColors.green)
                              : const StatusChip('Rejected', AdminColors.red)),
                          cellText(c.note.isNotEmpty
                              ? c.note
                              : (c.reviewedBy.isNotEmpty
                              ? 'by ${c.reviewedBy}'
                              : '')),
                          DataCell(c.isSubmitted
                              ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _verifyClaim(c),
                                child: const Text('Verify'),
                              ),
                              TextButton(
                                onPressed: () => _rejectClaim(c),
                                style: TextButton.styleFrom(
                                    foregroundColor: AdminColors.red),
                                child: const Text('Reject'),
                              ),
                            ],
                          )
                              : const SizedBox.shrink()),
                        ]),
                    ],
                  ),
                ),
              ] else if (_tab == 1)
                AdminCard(
                  title: 'Receipts (${receiptList.length}) · '
                      '${fmtMoney(receiptList.fold<int>(0, (n, r) => n + r.amount))}',
                  child: AdminTable(
                    emptyText: 'No payments have been recorded yet.',
                    columns: const [
                      'Date',
                      'Student',
                      'Class',
                      'Fee',
                      'Amount',
                      'Mode',
                    ],
                    rows: [
                      for (final r in receiptList)
                        DataRow(cells: [
                          cellText(fmtDate(r.date)),
                          cellText(s.studentName(r.studentId), bold: true),
                          cellText(s.studentById(r.studentId)?.className ?? ''),
                          cellText(r.title),
                          cellText(fmtMoney(r.amount), bold: true),
                          cellText(r.mode),
                        ]),
                    ],
                  ),
                )
              else ...[
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
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _status(f.status),
                                if (f.status != FeeStatus.paid &&
                                    _waitingFor(f).isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  const Text(
                                    'UTR sent',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: AdminColors.orange,
                                    ),
                                  ),
                                ],
                              ],
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (f.status != FeeStatus.paid) ...[
                                  TextButton(
                                    onPressed: () => _markPaid(f),
                                    child: const Text('Mark paid'),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined, size: 19),
                                    onPressed: () => _editFee(f),
                                  ),
                                ] else ...[
                                  TextButton(
                                    onPressed: () => _markUnpaid(f),
                                    child: const Text('Mark unpaid'),
                                  ),
                                ],
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

class _FeeMetricCard extends StatelessWidget {
  const _FeeMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.color,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color color;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(.09) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color.withOpacity(.55) : const Color(0xFFE8ECF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF172033))),
                    const SizedBox(height: 2),
                    Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF8490A3))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withOpacity(.8)),
            ],
          ),
        ),
      ),
    );
  }
}