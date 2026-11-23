import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_widgets.dart';

/// Diary: Teacher ने रोज publish केलेली class diary (Parent app मध्ये दिसणारी).
/// Admin ला पाहता येते आणि चुकीची diary delete करता येते.
class AdminDiaryScreen extends StatefulWidget {
  const AdminDiaryScreen({super.key});

  @override
  State<AdminDiaryScreen> createState() => _AdminDiaryScreenState();
}

class _AdminDiaryScreenState extends State<AdminDiaryScreen> {
  String? _classFilter;
  DateTime? _date;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _view(AdminDiary d) async {
    final s = AdminState.instance;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('${s.classNameOf(d.classId)} · ${fmtDate(d.date)}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.mood.isNotEmpty) ...[
                  StatusChip('Mood: ${d.mood}', AdminColors.purple),
                  const SizedBox(height: 12),
                ],
                if (d.items.isEmpty)
                  const Text('No activity lines.',
                      style: TextStyle(color: AdminColors.muted))
                else
                  for (final i in d.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              i.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: AdminColors.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(i.text,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                if (d.homeNote.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Note for home',
                      style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(d.homeNote, style: const TextStyle(fontSize: 13)),
                ],
                if (d.bring.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Please bring',
                      style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final b in d.bring) StatusChip(b, AdminColors.blue),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(AdminDiary d) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete this diary?',
      message: 'The diary of ${AdminState.instance.classNameOf(d.classId)} '
          'for ${fmtDate(d.date)} will be removed from the Parent app too.',
    );
    if (!ok) return;
    try {
      await AdminState.instance.deleteDiary(d);
      if (mounted) adminSnack(context, 'Diary deleted');
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
        final list = s.diaries.where((d) {
          if (_classFilter != null && d.classId != _classFilter) return false;
          if (_date != null &&
              !(d.date.year == _date!.year &&
                  d.date.month == _date!.month &&
                  d.date.day == _date!.day)) {
            return false;
          }
          return true;
        }).toList();

        final doneToday = s.classesWithDiaryToday;
        final missingToday =
        s.classes.where((c) => !doneToday.contains(c.id)).toList();

        return AdminPage(
          title: 'Diary',
          subtitle: 'Daily class diary published by teachers',
          actions: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(_date == null ? 'All dates' : fmtDate(_date)),
            ),
            if (_date != null)
              IconButton(
                tooltip: 'Clear date',
                onPressed: () => setState(() => _date = null),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
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
                    icon: Icons.menu_book_rounded,
                    label: 'Diaries published',
                    value: '${s.diaries.length}',
                    color: AdminColors.primary,
                  ),
                  StatCard(
                    icon: Icons.check_circle_rounded,
                    label: 'Published today',
                    value: '${doneToday.length}',
                    note: 'of ${s.classes.length} classes',
                    color: AdminColors.green,
                  ),
                  StatCard(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending today',
                    value: '${missingToday.length}',
                    note: missingToday.isEmpty
                        ? 'All classes done'
                        : missingToday.map((c) => c.className).join(', '),
                    color: AdminColors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AdminCard(
                title: 'Diary entries (${list.length})',
                child: AdminTable(
                  emptyText: 'No diary has been published yet.',
                  columns: const [
                    'Date',
                    'Class',
                    'Teacher',
                    'Activities',
                    'Mood',
                    'Home note',
                    '',
                  ],
                  rows: [
                    for (final d in list)
                      DataRow(cells: [
                        cellText(fmtDate(d.date), bold: true),
                        cellText(s.classNameOf(d.classId)),
                        cellText(s.teacherOfClass(d.classId)?.name ?? ''),
                        cellText('${d.items.length} items'),
                        cellText(d.mood),
                        cellText(d.homeNote),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'View',
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 19),
                              onPressed: () => _view(d),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 19, color: AdminColors.red),
                              onPressed: () => _delete(d),
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
}