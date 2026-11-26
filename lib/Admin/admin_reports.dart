import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'csv_download.dart';
import 'admin_widgets.dart';

/// Reports & Export: Admin ला school चा खरा data (Firestore मधून) Excel / Google Sheets
/// मध्ये घेण्यासाठी CSV स्वरूपात copy किंवा खरी .csv फाइल download करता येते. Preview सुद्धा screen वरच दिसतो.
enum _Report { students, attendance, fees, receipts, teachers, leaves }

class _Sheet {
  const _Sheet(this.headers, this.rows, this.summary);

  final List<String> headers;
  final List<List<String>> rows;
  final List<MapEntry<String, String>> summary;
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  _Report _report = _Report.students;
  String? _classFilter;
  String? _feeStatus; // null = all, 'paid' / 'due' / 'upcoming'
  DateTimeRange? _range;

  static const Map<_Report, String> _labels = {
    _Report.students: 'Students',
    _Report.attendance: 'Attendance',
    _Report.fees: 'Fees',
    _Report.receipts: 'Receipts',
    _Report.teachers: 'Teachers',
    _Report.leaves: 'Leave requests',
  };

  bool get _usesDates =>
      _report == _Report.attendance ||
          _report == _Report.receipts ||
          _report == _Report.leaves;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  bool _inRange(DateTime d) {
    if (_range == null) return true;
    final day = DateTime(d.year, d.month, d.day);
    final from = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
    final to = DateTime(_range!.end.year, _range!.end.month, _range!.end.day);
    return !day.isBefore(from) && !day.isAfter(to);
  }

  // ------------------------------------------------------------------
  // BUILD REPORT DATA
  // ------------------------------------------------------------------
  _Sheet _build(AdminState s) {
    switch (_report) {
      case _Report.students:
        return _students(s);
      case _Report.attendance:
        return _attendance(s);
      case _Report.fees:
        return _fees(s);
      case _Report.receipts:
        return _receipts(s);
      case _Report.teachers:
        return _teachers(s);
      case _Report.leaves:
        return _leaves(s);
    }
  }

  _Sheet _students(AdminState s) {
    final list = s.students
        .where((x) => _classFilter == null || x.classId == _classFilter)
        .toList()
      ..sort((a, b) {
        final c = s.classNameOf(a.classId).compareTo(s.classNameOf(b.classId));
        return c != 0 ? c : a.rollNo.compareTo(b.rollNo);
      });
    final joined = list.where(s.parentJoined).length;
    return _Sheet(
      const [
        'Class', 'Roll No', 'Student', 'Gender', 'Date of birth',
        'Blood group', 'Parent', 'Parent email', 'Phone', 'Allergy note',
        'Parent app joined',
      ],
      [
        for (final x in list)
          [
            s.classNameOf(x.classId),
            '${x.rollNo}',
            x.name,
            x.gender,
            fmtDate(x.dob),
            x.bloodGroup,
            x.parentName,
            x.parentEmail,
            x.contacts.isEmpty ? '' : x.contacts.first.phone,
            x.allergyNote,
            s.parentJoined(x) ? 'Yes' : 'No',
          ],
      ],
      [
        MapEntry('Students', '${list.length}'),
        MapEntry('Parents joined', '$joined'),
        MapEntry('Not joined yet', '${list.length - joined}'),
      ],
    );
  }

  _Sheet _attendance(AdminState s) {
    final list = s.attendance.where((a) {
      if (_classFilter != null && a.classId != _classFilter) return false;
      final d = DateTime.tryParse(a.day);
      if (d == null) return false;
      return _inRange(d);
    }).toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    final present = list.where((a) => a.status == 'P').length;
    final late = list.where((a) => a.status == 'L').length;
    final absent = list.where((a) => a.status == 'A').length;
    final pct = list.isEmpty ? 0 : ((present + late) * 100 ~/ list.length);
    String status(String v) =>
        v == 'P' ? 'Present' : v == 'L' ? 'Late' : v == 'A' ? 'Absent' : v;
    return _Sheet(
      const ['Date', 'Class', 'Student', 'Status', 'Reason'],
      [
        for (final a in list)
          [
            a.day,
            s.classNameOf(a.classId),
            s.studentById(a.studentId)?.name ?? '(removed student)',
            status(a.status),
            a.reason,
          ],
      ],
      [
        MapEntry('Records', '${list.length}'),
        MapEntry('Present', '$present'),
        MapEntry('Late', '$late'),
        MapEntry('Absent', '$absent'),
        MapEntry('Attendance', '$pct%'),
      ],
    );
  }

  _Sheet _fees(AdminState s) {
    final list = s.fees.where((f) {
      final st = s.studentById(f.studentId);
      if (_classFilter != null && st?.classId != _classFilter) return false;
      if (_feeStatus != null && _feeKey(f.status) != _feeStatus) return false;
      return true;
    }).toList();
    var billed = 0, paid = 0, due = 0;
    for (final f in list) {
      billed += f.amount;
      if (f.status == FeeStatus.paid) paid += f.amount;
      if (f.status == FeeStatus.due) due += f.amount;
    }
    return _Sheet(
      const ['Class', 'Student', 'Fee', 'Amount (₹)', 'Status', 'Due date'],
      [
        for (final f in list)
          [
            s.classNameOf(s.studentById(f.studentId)?.classId ?? ''),
            s.studentById(f.studentId)?.name ?? '',
            f.title,
            '${f.amount}',
            _feeKey(f.status),
            f.dueDate == null ? '' : fmtDate(f.dueDate),
          ],
      ],
      [
        MapEntry('Total billed', fmtMoney(billed)),
        MapEntry('Collected', fmtMoney(paid)),
        MapEntry('Pending', fmtMoney(due)),
      ],
    );
  }

  String _feeKey(FeeStatus st) => st == FeeStatus.paid
      ? 'paid'
      : st == FeeStatus.due
      ? 'due'
      : 'upcoming';

  _Sheet _receipts(AdminState s) {
    final list = s.receipts.where((r) {
      final st = s.studentById(r.studentId);
      if (_classFilter != null && st?.classId != _classFilter) return false;
      return _inRange(r.date);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = list.fold<int>(0, (a, r) => a + r.amount);
    return _Sheet(
      const ['Date', 'Class', 'Student', 'Fee', 'Amount (₹)', 'Mode'],
      [
        for (final r in list)
          [
            fmtDate(r.date),
            s.classNameOf(s.studentById(r.studentId)?.classId ?? ''),
            s.studentById(r.studentId)?.name ?? '',
            r.title,
            '${r.amount}',
            r.mode,
          ],
      ],
      [
        MapEntry('Receipts', '${list.length}'),
        MapEntry('Total collected', fmtMoney(total)),
      ],
    );
  }

  // नवीन: Parents चे रजेचे अर्ज (तारखेच्या range शी overlap होणारे).
  _Sheet _leaves(AdminState s) {
    bool overlaps(AdminLeave l) {
      if (_range == null) return true;
      final f = l.fromDate ?? l.toDate;
      final t = l.toDate ?? l.fromDate;
      if (f == null || t == null) return false;
      final from = DateTime(f.year, f.month, f.day);
      final to = DateTime(t.year, t.month, t.day);
      final rs = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      final re = DateTime(_range!.end.year, _range!.end.month, _range!.end.day);
      return !from.isAfter(re) && !to.isBefore(rs);
    }

    final list = s.leaves
        .where((l) =>
    (_classFilter == null || l.classId == _classFilter) && overlaps(l))
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
    int daysOf(AdminLeave l) => (l.fromDate == null || l.toDate == null)
        ? 0
        : l.toDate!.difference(l.fromDate!).inDays + 1;
    String statusOf(String v) =>
        v == 'approved' ? 'Approved' : v == 'declined' ? 'Declined' : 'Pending';
    final approved = list.where((l) => l.status == 'approved').length;
    final declined = list.where((l) => l.status == 'declined').length;
    final pending = list.length - approved - declined;
    return _Sheet(
      const [
        'From', 'To', 'Days', 'Class', 'Student', 'Parent', 'Reason',
        'Status', 'Teacher note', 'Applied on',
      ],
      [
        for (final l in list)
          [
            fmtDate(l.fromDate),
            fmtDate(l.toDate),
            '${daysOf(l)}',
            s.classNameOf(l.classId),
            l.studentName,
            l.parentName,
            l.reason,
            statusOf(l.status),
            l.teacherNote,
            fmtDate(l.createdAt),
          ],
      ],
      [
        MapEntry('Applications', '${list.length}'),
        MapEntry('Approved', '$approved'),
        MapEntry('Declined', '$declined'),
        MapEntry('Pending', '$pending'),
      ],
    );
  }

  _Sheet _teachers(AdminState s) {
    final list = s.teachers
        .where((t) => _classFilter == null || t.classId == _classFilter)
        .toList();
    final pending = list.where((t) => !t.approved).length;
    return _Sheet(
      const [
        'Name', 'Email', 'Phone', 'School', 'Employee ID', 'Class',
        'Status', 'Registered on',
      ],
      [
        for (final t in list)
          [
            t.name,
            t.email,
            t.phone,
            t.schoolName,
            t.employeeId,
            t.className,
            t.approved ? 'Approved' : 'Pending',
            fmtDate(t.createdAt),
          ],
      ],
      [
        MapEntry('Teachers', '${list.length}'),
        MapEntry('Approved', '${list.length - pending}'),
        MapEntry('Pending approval', '$pending'),
      ],
    );
  }

  // ------------------------------------------------------------------
  // CSV
  // ------------------------------------------------------------------
  String _cell(String v) {
    final needsQuotes =
        v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r');
    final safe = v.replaceAll('"', '""');
    return needsQuotes ? '"$safe"' : safe;
  }

  String _csv(_Sheet sheet) {
    final b = StringBuffer()..writeln(sheet.headers.map(_cell).join(','));
    for (final r in sheet.rows) {
      b.writeln(r.map(_cell).join(','));
    }
    return b.toString();
  }

  Future<void> _copy(_Sheet sheet) async {
    if (sheet.rows.isEmpty) {
      adminSnack(context, 'Nothing to export for these filters.', error: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: _csv(sheet)));
    if (!mounted) return;
    adminSnack(
      context,
      '${sheet.rows.length} rows copied. Paste into Excel or Google Sheets.',
    );
  }

  /// खरी .csv फाइल download (Web). जमलं नाही तर आपोआप clipboard वर copy होतं.
  Future<void> _download(_Sheet sheet) async {
    if (sheet.rows.isEmpty) {
      adminSnack(context, 'Nothing to export for these filters.', error: true);
      return;
    }
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = 'little_steps_${_report.name}_'
        '${n.year}${two(n.month)}${two(n.day)}.csv';
    final ok = downloadCsvFile(name, _csv(sheet));
    if (ok) {
      adminSnack(context, '$name downloaded (${sheet.rows.length} rows).');
    } else {
      await _copy(sheet);
    }
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final sheet = _build(s);
        const previewMax = 15;

        return AdminPage(
          title: 'Reports & Export',
          subtitle: 'Real school data as a CSV file for Excel / Google Sheets',
          actions: [
            AdminDropdown<String?>(
              label: 'Class',
              width: 200,
              value: _classFilter,
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All classes')),
                for (final c in s.classes)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.className)),
              ],
              onChanged: (v) => setState(() => _classFilter = v),
            ),
            if (_usesDates) ...[
              OutlinedButton.icon(
                onPressed: _pickRange,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(_range == null
                    ? 'All dates'
                    : '${fmtDate(_range!.start)} – ${fmtDate(_range!.end)}'),
              ),
              if (_range != null)
                IconButton(
                  tooltip: 'Clear dates',
                  onPressed: () => setState(() => _range = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
            if (_report == _Report.fees)
              AdminDropdown<String?>(
                label: 'Fee status',
                width: 180,
                value: _feeStatus,
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('All')),
                  DropdownMenuItem<String?>(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem<String?>(value: 'due', child: Text('Due')),
                  DropdownMenuItem<String?>(
                      value: 'upcoming', child: Text('Upcoming')),
                ],
                onChanged: (v) => setState(() => _feeStatus = v),
              ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorBanner(s.lastError),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _Report.values)
                    ChoiceChip(
                      label: Text(_labels[r]!),
                      selected: _report == r,
                      onSelected: (_) => setState(() => _report = r),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AdminResponsiveGrid(
                minItemWidth: 180,
                children: [
                  for (var i = 0; i < sheet.summary.length; i++)
                    StatCard(
                      icon: Icons.insights_rounded,
                      label: sheet.summary[i].key,
                      value: sheet.summary[i].value,
                      color: [
                        AdminColors.primary,
                        AdminColors.green,
                        AdminColors.orange,
                        AdminColors.blue,
                        AdminColors.purple,
                      ][i % 5],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AdminCard(
                title: '${_labels[_report]} · ${sheet.rows.length} rows',
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copy(sheet),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44)),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy CSV'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _download(sheet),
                      style: adminPrimaryButton(),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download CSV'),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminTable(
                      columns: sheet.headers,
                      emptyText: 'No data for these filters.',
                      rows: [
                        for (final r in sheet.rows.take(previewMax))
                          DataRow(cells: [
                            for (final c in r) DataCell(Text(c)),
                          ]),
                      ],
                    ),
                    if (sheet.rows.length > previewMax)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Showing first $previewMax of ${sheet.rows.length} rows. '
                              'Copy / Download CSV includes all rows.',
                          style: const TextStyle(
                              color: AdminColors.muted, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}