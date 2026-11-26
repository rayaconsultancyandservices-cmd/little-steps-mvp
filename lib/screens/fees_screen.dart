import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/page_app_bar.dart';

// =====================================================================
// Teacher चा "Fees" screen (नवीन)
//  - वर्गाचा सारांश: pending / collected / किती मुलांची fee बाकी
//  - प्रत्येक मुलाची fee यादी -> fee जोडा, बदला, काढा, "paid" करा (receipt तयार)
//  - संपूर्ण वर्गाला एकच fee एकदम जोडणे
// इथे केलेला बदल Parent app मध्ये लगेच दिसतो.
//
// NEW (Payment requests):
//  - Parent ने UPI ने भरून पाठवलेली request (UTR सह) इथे दिसते
//  - "Verify" -> fee आपोआप paid + receipt (UTR सहित) तयार + request verified
//  - "Reject" -> कारण (पर्यायी) लिहिता येते, Parent ला दिसते
//  - वर्गाच्या यादीत "To verify" filter + वर banner
//  - AppBar मधून School चा UPI ID / नाव सेट करता येतो (Parent चं "Pay online" चालू होतं)
//  - Manual "Mark paid" केल्यावर त्या fee ची submitted request आपोआप verified होते
// =====================================================================

const Color _primary = Color(0xFF168C80);
const Color _dark = Color(0xFF183B45);
const Color _muted = Color(0xFF82918D);
const Color _red = Color(0xFFE36B61);
const Color _orange = Color(0xFFD99437);
const Color _green = Color(0xFF269B73);

const List<String> _payModes = ['Cash', 'UPI', 'Card', 'Bank transfer', 'Cheque'];

/// 12500 -> ₹12,500  (भारतीय पद्धतीने)
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
  return '${amount < 0 ? '-' : ''}₹$r';
}

String _date(DateTime d) => '${d.day} ${AppState.monthShort(d.month)} ${d.year}';

int _dueTotal(List<FeeItem> fees) => fees
    .where((f) => f.status == FeeStatus.due)
    .fold<int>(0, (sum, f) => sum + f.amount);

int _paidTotal(List<FeeItem> fees) => fees
    .where((f) => f.status == FeeStatus.paid)
    .fold<int>(0, (sum, f) => sum + f.amount);

InputDecoration _fieldDec(String label, {String? hint, String? prefix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

/// 3:07 PM
String _time(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

/// Parent चा UPI ID वैध आहे का (Parent app मधला नियम तोच).
final RegExp _upiRe = RegExp(r'^[A-Za-z0-9.\-_]{2,}@[A-Za-z]{2,}$');

// =====================================================================
// Parent ची payment request  (students/{studentId}/payments/{id})
// =====================================================================
class _Claim {
  const _Claim({
    required this.id,
    required this.studentId,
    required this.feeId,
    required this.title,
    required this.amount,
    required this.utr,
    required this.status,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final String studentId;
  final String feeId;
  final String title;
  final int amount;
  final String utr;

  /// submitted | verified | rejected
  final String status;
  final DateTime createdAt;
  final String note;

  bool get isSubmitted => status == 'submitted';

  factory _Claim.fromDoc(
      String studentId, QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    final ts = x['createdAt'];
    final amt = x['amount'];
    return _Claim(
      id: d.id,
      studentId: studentId,
      feeId: (x['feeId'] ?? '').toString(),
      title: (x['title'] ?? '').toString(),
      amount: amt is num ? amt.toInt() : 0,
      utr: (x['utr'] ?? '').toString(),
      status: (x['status'] ?? 'submitted').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      note: (x['note'] ?? '').toString(),
    );
  }
}

/// एका मुलाच्या सर्व payment requests (नवीन आधी).
Future<List<_Claim>> _loadClaims(String studentId) async {
  final snap = await FirebaseFirestore.instance
      .collection('students')
      .doc(studentId)
      .collection('payments')
      .get();
  return [for (final d in snap.docs) _Claim.fromDoc(studentId, d)]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

// =====================================================================
// 1) वर्गाची Fees यादी
// =====================================================================
class TeacherFeesScreen extends StatefulWidget {
  const TeacherFeesScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<TeacherFeesScreen> createState() => _TeacherFeesScreenState();
}

class _TeacherFeesScreenState extends State<TeacherFeesScreen>
    with WidgetsBindingObserver {
  Map<String, List<FeeItem>> _fees = {};
  bool _loading = true;
  Map<String, List<_Claim>> _claims = {};
  bool _claimsFailed = false;
  int _filter = 0; // 0 सर्व, 1 बाकी (dues), 2 clear, 3 verify करायच्या requests
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App परत उघडल्यावर (background -> foreground) नवीन payment requests
  /// आपोआप घेतो, spinner न दाखवता.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final data = await AppState.instance.loadClassFees();

    // Parent च्या payment requests (प्रत्येक मुलाच्या `payments` मधून).
    final claims = <String, List<_Claim>>{};
    _claimsFailed = false;
    await Future.wait([
      for (final s in AppState.instance.students) _loadClaimsFor(s.id, claims),
    ]);

    if (!mounted) return;
    setState(() {
      _fees = data;
      _claims = claims;
      _loading = false;
    });
  }

  Future<void> _loadClaimsFor(String id, Map<String, List<_Claim>> out) async {
    try {
      out[id] = await _loadClaims(id);
    } catch (_) {
      _claimsFailed = true;
    }
  }

  int _toVerify(String studentId) =>
      (_claims[studentId] ?? const <_Claim>[]).where((c) => c.isSubmitted).length;

  /// School चा UPI ID / नाव सेट करतो (`classes/{classId}`), Parent चं "Pay online" यावर चालतं.
  Future<void> _editUpi() async {
    final classId = AppState.instance.classId;
    if (classId.isEmpty) {
      _snack('Your class was not found.');
      return;
    }
    var upi = '';
    var name = '';
    try {
      final d = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();
      final m = d.data();
      upi = (m?['upiId'] ?? '').toString();
      name = (m?['upiName'] ?? '').toString();
    } catch (_) {}
    if (!mounted) return;

    final res = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _UpiDialog(upiId: upi, upiName: name),
    );
    if (res == null || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('classes').doc(classId).set(
        {'upiId': res.$1, 'upiName': res.$2},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      _snack(res.$1.isEmpty
          ? 'Online payment turned off. Parents will pay at school.'
          : 'School UPI saved. Parents can now pay online.');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not save UPI: $e');
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _addForClass() async {
    final students = AppState.instance.students;
    if (students.isEmpty) {
      _snack('Add students to your class first.');
      return;
    }
    final input = await showDialog<_FeeInput>(
      context: context,
      builder: (_) => _FeeFormDialog(
        heading: 'Add fee · whole class',
        hint: 'This fee will be added for all ${students.length} students.',
      ),
    );
    if (input == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await AppState.instance.addFeeForStudents(
        [for (final s in students) s.id],
        input.title,
        input.amount,
        input.dueDate,
        upcoming: input.upcoming,
      );
      if (!mounted) return;
      _snack('Fee added for ${students.length} students.');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not add fee: $e');
    }
    await _load();
  }

  Future<void> _openStudent(ChildInfo c) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StudentFeesPage(
          studentId: c.id,
          studentName: c.name,
          rollNo: c.rollNo,
          classClaims: _claims,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildPageAppBar(
        title: 'Fees',
        subtitle: 'Changes show instantly in the Parent app',
        onBack: widget.onBack,
        actions: [
          IconButton(
            tooltip: 'School UPI for online payments',
            onPressed: _loading ? null : _editUpi,
            icon: const Icon(Icons.qr_code_2_rounded, color: _primary),
          ),
          IconButton(
            tooltip: 'Add fee for whole class',
            onPressed: _loading ? null : _addForClass,
            icon: const Icon(Icons.playlist_add_rounded, color: _primary),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final students = AppState.instance.students;

          var totalDue = 0;
          var totalPaid = 0;
          var withDues = 0;
          var toVerify = 0;
          for (final s in students) {
            final f = _fees[s.id] ?? const <FeeItem>[];
            final d = _dueTotal(f);
            totalDue += d;
            totalPaid += _paidTotal(f);
            if (d > 0) withDues++;
            toVerify += _toVerify(s.id);
          }

          final q = _query.trim().toLowerCase();
          final shown = students.where((s) {
            if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
            final due = _dueTotal(_fees[s.id] ?? const <FeeItem>[]);
            if (_filter == 1 && due == 0) return false;
            if (_filter == 2 && due > 0) return false;
            if (_filter == 3 && _toVerify(s.id) == 0) return false;
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: _load,
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
                        Row(
                          children: [
                            _stat('Pending', _money(totalDue), _orange),
                            const SizedBox(width: 10),
                            _stat('Collected', _money(totalPaid), _green),
                            const SizedBox(width: 10),
                            _stat('With dues', '$withDues', _red),
                          ],
                        ),
                        if (toVerify > 0) ...[
                          const SizedBox(height: 12),
                          _requestsBanner(toVerify),
                        ],
                        const SizedBox(height: 14),
                        TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Search student',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                              const BorderSide(color: Color(0xFFD4E5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                              const BorderSide(color: Color(0xFFD4E5E1)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip('All', 0),
                            _chip('Dues', 1),
                            _chip('Clear', 2),
                            _chip(
                              toVerify > 0 ? 'To verify ($toVerify)' : 'To verify',
                              3,
                            ),
                          ],
                        ),
                        if (_claimsFailed)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Payment requests could not be loaded. '
                                  'Please publish the latest Firestore rules.',
                              style: TextStyle(fontSize: 11, color: _red),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        else if (students.isEmpty)
                          _emptyNote('No students in your class yet.')
                        else if (shown.isEmpty)
                            _emptyNote('No students match this filter.')
                          else
                            for (final s in shown) _studentTile(s),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _requestsBanner(int count) => InkWell(
    onTap: () => setState(() => _filter = 3),
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions_rounded, color: _orange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 payment request is waiting for your verification'
                  : '$count payment requests are waiting for your verification',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _orange),
        ],
      ),
    ),
  );

  Widget _emptyNote(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Text(text, style: const TextStyle(fontSize: 12, color: _muted)),
    ),
  );

  Widget _stat(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: _muted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _chip(String label, int index) => ChoiceChip(
    label: Text(label),
    selected: _filter == index,
    showCheckmark: false,
    selectedColor: _primary,
    backgroundColor: const Color(0xFFE4F3EF),
    side: BorderSide.none,
    labelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: _filter == index ? Colors.white : _primary,
    ),
    onSelected: (_) => setState(() => _filter = index),
  );

  Widget _studentTile(ChildInfo s) {
    final fees = _fees[s.id] ?? const <FeeItem>[];
    final due = _dueTotal(fees);

    String subtitle;
    Color color;
    if (fees.isEmpty) {
      subtitle = 'No fees added';
      color = _muted;
    } else if (due > 0) {
      subtitle = '${_money(due)} due';
      color = _orange;
    } else {
      subtitle = 'All clear';
      color = _green;
    }

    final tv = _toVerify(s.id);
    final parts = s.name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? '?'
        : (parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'
        : parts.first[0])
        .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: () => _openStudent(s),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE4F3EF),
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _primary,
            ),
          ),
        ),
        title: Text(
          s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        subtitle: Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            children: [
              TextSpan(text: 'Roll ${s.rollNo}  •  $subtitle'),
              if (tv > 0)
                TextSpan(
                  text: '  •  $tv to verify',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _orange,
                  ),
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
      ),
    );
  }
}

// =====================================================================
// 2) एका विद्यार्थ्याची Fees
// =====================================================================
class _StudentFeesPage extends StatefulWidget {
  const _StudentFeesPage({
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    this.classClaims = const <String, List<_Claim>>{},
  });

  final String studentId;
  final String studentName;
  final int rollNo;

  /// वर्गातल्या सर्व मुलांच्या payment requests (duplicate UTR तपासण्यासाठी).
  final Map<String, List<_Claim>> classClaims;

  @override
  State<_StudentFeesPage> createState() => _StudentFeesPageState();
}

class _StudentFeesPageState extends State<_StudentFeesPage> {
  List<FeeItem> _fees = [];
  List<FeeReceipt> _receipts = [];
  List<_Claim> _claims = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        AppState.instance.loadStudentFees(widget.studentId),
        AppState.instance.loadStudentReceipts(widget.studentId),
        // Requests लोड न झाल्या (rules नसतील) तरी fees screen चालू राहावा.
        _loadClaims(widget.studentId).catchError((Object _) => <_Claim>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _fees = results[0] as List<FeeItem>;
        _receipts = results[1] as List<FeeReceipt>;
        _claims = results[2] as List<_Claim>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      _snack(done);
    } catch (e) {
      if (!mounted) return;
      _snack('Something went wrong: $e');
    }
    await _load();
  }

  Future<void> _addFee() async {
    final input = await showDialog<_FeeInput>(
      context: context,
      builder: (_) => _FeeFormDialog(
        heading: 'Add fee · ${widget.studentName}',
      ),
    );
    if (input == null || !mounted) return;
    await _run(
          () => AppState.instance.addFee(
        widget.studentId,
        input.title,
        input.amount,
        input.dueDate,
        order: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        upcoming: input.upcoming,
      ),
      'Fee added.',
    );
  }

  Future<void> _editFee(FeeItem f) async {
    final input = await showDialog<_FeeInput>(
      context: context,
      builder: (_) => _FeeFormDialog(
        heading: 'Edit fee · ${widget.studentName}',
        existing: f,
      ),
    );
    if (input == null || !mounted) return;
    await _run(
          () => AppState.instance.updateFee(
        widget.studentId,
        f.id,
        title: input.title,
        amount: input.amount,
        dueDate: input.dueDate,
        upcoming: input.upcoming,
      ),
      'Fee updated.',
    );
  }

  Future<void> _deleteFee(FeeItem f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete this fee?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '${f.title} (${_money(f.amount)}) will be removed for '
              '${widget.studentName}.',
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
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
          () => AppState.instance.deleteFee(widget.studentId, f.id),
      'Fee deleted.',
    );
  }

  Future<void> _markPaid(FeeItem f) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (_) => _PayDialog(fee: f),
    );
    if (mode == null || !mounted) return;
    await _run(
          () async {
        await AppState.instance.markFeePaid(widget.studentId, f, mode);
        // या fee साठी Parent ची "submitted" request असेल तर ती सुद्धा verified करतो.
        for (final c in _claims) {
          if (c.feeId == f.id && c.isSubmitted) {
            try {
              await FirebaseFirestore.instance
                  .collection('students')
                  .doc(widget.studentId)
                  .collection('payments')
                  .doc(c.id)
                  .update({
                'status': 'verified',
                'reviewedAt': Timestamp.now(),
                'reviewedBy': AppState.instance.teacherName,
              });
            } catch (_) {}
          }
        }
      },
      'Marked as paid. Receipt created.',
    );
  }

  /// Parent ची payment request verify: fee paid + receipt (UTR सह) + request verified.
  /// हाच UTR वर्गात आधीच verified झालेला असेल तर त्या मुलाचं नाव देतो.
  String? _duplicateOf(_Claim c) {
    final key = c.utr.trim().toUpperCase();
    if (key.isEmpty) return null;
    final pool = <_Claim>[
      ..._claims,
      for (final l in widget.classClaims.values) ...l,
    ];
    for (final o in pool) {
      if (o.id == c.id && o.studentId == c.studentId) continue;
      if (o.status != 'verified') continue;
      if (o.utr.trim().toUpperCase() != key) continue;
      if (o.studentId == widget.studentId) return widget.studentName;
      for (final s in AppState.instance.students) {
        if (s.id == o.studentId) return s.name;
      }
      return 'another student';
    }
    return null;
  }

  Future<void> _verifyClaim(_Claim c) async {
    final matches = _fees.where((f) => f.id.isNotEmpty && f.id == c.feeId);
    if (matches.isEmpty) {
      _snack('The fee for this request no longer exists. '
          'You can reject the request.');
      return;
    }
    final fee = matches.first;
    final already = fee.status == FeeStatus.paid;
    final amountDiffers = fee.amount != c.amount;
    final dupOf = _duplicateOf(c);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Verify payment?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '${fee.title}\n'
              'Amount: ${_money(fee.amount)}\n'
              'UTR: ${c.utr}\n\n'
              '${already ? 'This fee is already marked paid. The request will just be marked verified.' : 'The fee will be marked paid and a receipt (mode UPI) will be created for the parent.'}'
              '${amountDiffers ? '\n\nNote: the parent paid for ${_money(c.amount)}, but the fee is now ${_money(fee.amount)}. Check your bank before verifying.' : ''}'
              '${dupOf != null ? '\n\nWarning: this UTR was already verified for $dupOf. Verify again only if you are sure it is a different payment.' : ''}'
              '\n\nVerify only after you see this UTR in your bank / UPI app.',
          style: const TextStyle(fontSize: 12.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dupOf != null ? _orange : _green,
              foregroundColor: Colors.white,
            ),
            child: Text(dupOf != null ? 'Verify anyway' : 'Verify'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await _run(
          () async {
        final db = FirebaseFirestore.instance;
        final sRef = db.collection('students').doc(widget.studentId);
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
          'reviewedBy': AppState.instance.teacherName,
        });
        await batch.commit();
      },
      already
          ? 'Request marked as verified.'
          : 'Payment verified. Fee marked paid and receipt created.',
    );
  }

  /// Parent ची payment request reject (कारण पर्यायी, Parent ला दिसतं).
  Future<void> _rejectClaim(_Claim c) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(claim: c),
    );
    if (reason == null || !mounted) return;
    await _run(
          () => FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .collection('payments')
          .doc(c.id)
          .update({
        'status': 'rejected',
        'note': reason,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': AppState.instance.teacherName,
      }),
      'Request rejected. The parent can see your note.',
    );
  }

  Future<void> _markUnpaid(FeeItem f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Mark as unpaid?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '${f.title} (${_money(f.amount)}) will go back to pending and '
              'its receipt will be removed for ${widget.studentName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark unpaid'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
          () => AppState.instance.markFeeUnpaid(widget.studentId, f),
      'Marked as unpaid. Receipt removed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _fees.where((f) => f.status != FeeStatus.paid).toList();
    final paid = _fees.where((f) => f.status == FeeStatus.paid).toList();
    final submitted = _claims.where((c) => c.isSubmitted).toList();
    final reviewed = _claims.where((c) => !c.isSubmitted).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildPageAppBar(
        title: widget.studentName,
        subtitle: 'Roll ${widget.rollNo}  •  Fees',
        onBack: () => Navigator.of(context).pop(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addFee,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add fee',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null
          ? _buildError()
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _summary('Due', _money(_dueTotal(_fees)), _orange),
                        const SizedBox(width: 10),
                        _summary('Paid', _money(_paidTotal(_fees)), _green),
                      ],
                    ),
                    if (submitted.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _title('Payment requests to verify (${submitted.length})'),
                      const SizedBox(height: 8),
                      for (final c in submitted) _claimCard(c),
                    ],
                    const SizedBox(height: 18),
                    _title('Pending (${pending.length})'),
                    const SizedBox(height: 8),
                    if (pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                        child: Text(
                          'No pending fees.',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      )
                    else
                      for (final f in pending) _pendingCard(f),
                    if (paid.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _title('Paid (${paid.length})'),
                      const SizedBox(height: 8),
                      for (final f in paid) _paidCard(f),
                    ],
                    if (reviewed.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _title('Earlier payment requests (${reviewed.length})'),
                      const SizedBox(height: 8),
                      for (final c in reviewed) _reviewedCard(c),
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

  Widget _claimCard(_Claim c) {
    FeeItem? fee;
    for (final f in _fees) {
      if (f.id.isNotEmpty && f.id == c.feeId) {
        fee = f;
        break;
      }
    }
    String? warn;
    if (fee == null) {
      warn = 'The fee for this request was deleted.';
    } else if (fee.status == FeeStatus.paid) {
      warn = 'This fee is already marked paid.';
    } else if (fee.amount != c.amount) {
      warn = 'Fee is now ${_money(fee.amount)}, parent paid ${_money(c.amount)}.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _orange.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.title.isEmpty ? 'Fee payment' : c.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
              ),
              Text(
                _money(c.amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'UTR: ${c.utr}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: c.utr));
                  if (mounted) _snack('UTR copied.');
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded, size: 16, color: _primary),
                ),
              ),
            ],
          ),
          Text(
            'Sent ${_date(c.createdAt)}, ${_time(c.createdAt)}  •  UPI',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          if (warn != null) ...[
            const SizedBox(height: 6),
            Text(
              warn,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _red,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _rejectClaim(c),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: const BorderSide(color: _red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: fee == null ? null : () => _verifyClaim(c),
                icon: const Icon(Icons.verified_rounded, size: 16),
                label: const Text('Verify'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewedCard(_Claim c) {
    final ok = c.status == 'verified';
    final color = ok ? _green : _red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.verified_rounded : Icons.cancel_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.title.isEmpty ? 'Fee payment' : c.title}  •  ${_money(c.amount)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'UTR ${c.utr}  •  ${_date(c.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
                if (!ok && c.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Note: ${c.note}',
                      style: const TextStyle(fontSize: 11, color: _red),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            ok ? 'Verified' : 'Rejected',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: _red),
          const SizedBox(height: 12),
          Text(
            'Could not load fees.\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    ),
  );

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: _dark,
      ),
    ),
  );

  Widget _summary(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pendingCard(FeeItem f) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = f.status == FeeStatus.due &&
        f.dueDate != null &&
        f.dueDate!.isBefore(today);
    final upcoming = f.status == FeeStatus.upcoming;

    final label = upcoming ? 'Upcoming' : (overdue ? 'Overdue' : 'Due');
    final color = upcoming ? _muted : (overdue ? _red : _orange);

    _Claim? sent;
    for (final c in _claims) {
      if (c.isSubmitted && f.id.isNotEmpty && c.feeId == f.id) {
        sent = c;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  f.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
              ),
              Text(
                _money(f.amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: _muted),
                onSelected: (v) {
                  if (v == 'edit') _editFee(f);
                  if (v == 'delete') _deleteFee(f);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: _red)),
                  ),
                ],
              ),
            ],
          ),
          if (sent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Parent sent a payment request (UTR ${sent.utr}). '
                    'Verify it above.',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _orange,
                ),
              ),
            ),
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                f.dueDate == null
                    ? 'No due date'
                    : 'Due ${_date(f.dueDate!)}',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _markPaid(f),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Mark paid'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paidCard(FeeItem f) {
    FeeReceipt? receipt;
    for (final r in _receipts) {
      if (r.feeId == f.id) {
        receipt = r;
        break;
      }
    }
    final detail = receipt == null
        ? 'Paid'
        : 'Paid ${_date(receipt.date)}'
        '${receipt.mode.isEmpty ? '' : '  •  ${receipt.mode}'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _green, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(detail,
                    style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          Text(
            _money(f.amount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _green,
            ),
          ),
          // नवीन: चुकीचं "paid" परत करण्यासाठी
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _muted),
            onSelected: (v) {
              if (v == 'unpaid') _markUnpaid(f);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'unpaid', child: Text('Mark unpaid')),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Fee form dialog (जोडणे + बदलणे दोन्हीसाठी)
// =====================================================================
class _FeeInput {
  const _FeeInput(this.title, this.amount, this.dueDate, this.upcoming);

  final String title;
  final int amount;
  final DateTime? dueDate;
  final bool upcoming;
}

class _FeeFormDialog extends StatefulWidget {
  const _FeeFormDialog({required this.heading, this.existing, this.hint});

  final String heading;
  final FeeItem? existing;
  final String? hint;

  @override
  State<_FeeFormDialog> createState() => _FeeFormDialogState();
}

class _FeeFormDialogState extends State<_FeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
  TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null ? '' : '${widget.existing!.amount}',
  );
  late DateTime? _due = widget.existing?.dueDate;
  late bool _upcoming = widget.existing?.status == FeeStatus.upcoming;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    var first = DateTime(now.year - 1);
    if (_due != null && _due!.isBefore(first)) first = _due!;
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: first,
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (d != null) setState(() => _due = DateTime(d.year, d.month, d.day));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _FeeInput(
        _title.text.trim(),
        int.parse(_amount.text.trim()),
        _due,
        _upcoming,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        widget.heading,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.hint != null) ...[
                Text(widget.hint!,
                    style: const TextStyle(fontSize: 11.5, color: _muted)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                _fieldDec('Fee title', hint: 'e.g. Term 2 Tuition Fee'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter a fee title'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                decoration: _fieldDec('Amount', prefix: '₹ '),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Enter an amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDue,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _fieldDec('Due date (optional)'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _due == null ? 'Not set' : _date(_due!),
                          style: TextStyle(
                            fontSize: 14,
                            color: _due == null ? _muted : _dark,
                          ),
                        ),
                      ),
                      if (_due != null)
                        InkWell(
                          onTap: () => setState(() => _due = null),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: _muted),
                        )
                      else
                        const Icon(Icons.calendar_month_rounded,
                            size: 18, color: _primary),
                    ],
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _upcoming,
                activeThumbColor: _primary,
                onChanged: (v) => setState(() => _upcoming = v),
                title: const Text(
                  'Upcoming (not due yet)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Parents see it as upcoming, not as pending.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

// =====================================================================
// "Mark as paid" dialog: payment mode निवड
// =====================================================================
class _PayDialog extends StatefulWidget {
  const _PayDialog({required this.fee});

  final FeeItem fee;

  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  String _mode = _payModes.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Mark as paid',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.fee.title} · ${_money(widget.fee.amount)}\n'
                'A receipt will be created and shown to the parent.',
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: _muted),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: _fieldDec('Payment mode'),
            items: [
              for (final m in _payModes)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) => setState(() => _mode = v ?? _mode),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _mode),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: const Text('Mark paid'),
        ),
      ],
    );
  }
}

// =====================================================================
// School UPI dialog (Parent ला "Pay online" देण्यासाठी)
// =====================================================================
class _UpiDialog extends StatefulWidget {
  const _UpiDialog({required this.upiId, required this.upiName});

  final String upiId;
  final String upiName;

  @override
  State<_UpiDialog> createState() => _UpiDialogState();
}

class _UpiDialogState extends State<_UpiDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id =
  TextEditingController(text: widget.upiId);
  late final TextEditingController _name =
  TextEditingController(text: widget.upiName);

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final id = _id.text.trim();
    Navigator.pop(context, (id, id.isEmpty ? '' : _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'School UPI for online payments',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parents will see "Pay online" and pay to this UPI ID. '
                    'Leave it empty to turn online payment off.',
                style: TextStyle(fontSize: 11.5, height: 1.5, color: _muted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _id,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: _fieldDec('UPI ID', hint: 'e.g. littlesteps@upi'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return _upiRe.hasMatch(t) ? null : 'Enter a valid UPI ID';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration:
                _fieldDec('Account name (optional)', hint: 'School name'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// =====================================================================
// Reject dialog: कारण (पर्यायी) - Parent ला दिसतं
// =====================================================================
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.claim});

  final _Claim claim;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Reject payment request?',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.claim.title}  •  ${_money(widget.claim.amount)}\n'
                'UTR: ${widget.claim.utr}',
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: _muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 120,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _fieldDec(
              'Reason for parent (optional)',
              hint: 'e.g. UTR not found in bank',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}