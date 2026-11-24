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

// =====================================================================
// 1) वर्गाची Fees यादी
// =====================================================================
class TeacherFeesScreen extends StatefulWidget {
  const TeacherFeesScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<TeacherFeesScreen> createState() => _TeacherFeesScreenState();
}

class _TeacherFeesScreenState extends State<TeacherFeesScreen> {
  Map<String, List<FeeItem>> _fees = {};
  bool _loading = true;
  int _filter = 0; // 0 सर्व, 1 बाकी (dues), 2 clear
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final data = await AppState.instance.loadClassFees();
    if (!mounted) return;
    setState(() {
      _fees = data;
      _loading = false;
    });
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
          for (final s in students) {
            final f = _fees[s.id] ?? const <FeeItem>[];
            final d = _dueTotal(f);
            totalDue += d;
            totalPaid += _paidTotal(f);
            if (d > 0) withDues++;
          }

          final q = _query.trim().toLowerCase();
          final shown = students.where((s) {
            if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
            final due = _dueTotal(_fees[s.id] ?? const <FeeItem>[]);
            if (_filter == 1 && due == 0) return false;
            if (_filter == 2 && due > 0) return false;
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
                          ],
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
        subtitle: Text(
          'Roll ${s.rollNo}  •  $subtitle',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
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
  });

  final String studentId;
  final String studentName;
  final int rollNo;

  @override
  State<_StudentFeesPage> createState() => _StudentFeesPageState();
}

class _StudentFeesPageState extends State<_StudentFeesPage> {
  List<FeeItem> _fees = [];
  List<FeeReceipt> _receipts = [];
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
      ]);
      if (!mounted) return;
      setState(() {
        _fees = results[0] as List<FeeItem>;
        _receipts = results[1] as List<FeeReceipt>;
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
          () => AppState.instance.markFeePaid(widget.studentId, f, mode),
      'Marked as paid. Receipt created.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _fees.where((f) => f.status != FeeStatus.paid).toList();
    final paid = _fees.where((f) => f.status == FeeStatus.paid).toList();

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
                  ],
                ),
              ),
            ),
          ],
        ),
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