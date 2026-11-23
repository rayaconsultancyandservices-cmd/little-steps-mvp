import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_widgets.dart';

/// Parents: प्रत्येक विद्यार्थ्याचा पालक + त्यांनी Parent app मध्ये login केलं का.
class AdminParentsScreen extends StatefulWidget {
  const AdminParentsScreen({super.key});

  @override
  State<AdminParentsScreen> createState() => _AdminParentsScreenState();
}

class _AdminParentsScreenState extends State<AdminParentsScreen> {
  final _search = TextEditingController();
  String _q = '';
  int _filter = 0; // 0 all, 1 joined, 2 not yet

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final joined = s.parentsJoinedCount;

        final list = s.students.where((c) {
          final isJoined = s.parentJoined(c);
          if (_filter == 1 && !isJoined) return false;
          if (_filter == 2 && isJoined) return false;
          if (_q.isEmpty) return true;
          return '${c.parentName} ${c.parentEmail} ${c.name}'
              .toLowerCase()
              .contains(_q);
        }).toList();

        return AdminPage(
          title: 'Parents',
          subtitle: '$joined of ${s.students.length} families are on the Parent app',
          actions: [
            AdminSearchField(
              controller: _search,
              hint: 'Search parent, email or child…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('All')),
                ButtonSegment(value: 1, label: Text('Joined')),
                ButtonSegment(value: 2, label: Text('Not yet')),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
          ],
          child: Column(
            children: [
              ErrorBanner(s.lastError),
              AdminCard(
                child: AdminTable(
                  emptyText: s.students.isEmpty
                      ? 'No students yet, so there are no parents to show.'
                      : 'No parent matches the filter.',
                  columns: const [
                    'Parent',
                    'Email',
                    'Phone',
                    'Child',
                    'Class',
                    'Parent app',
                  ],
                  rows: [
                    for (final c in list)
                      DataRow(cells: [
                        cellText(c.parentName, bold: true),
                        cellText(c.parentEmail),
                        cellText(c.contacts.isEmpty ? '' : c.contacts.first.phone),
                        cellText(c.name),
                        cellText(c.className),
                        DataCell(s.parentJoined(c)
                            ? const StatusChip('Joined', AdminColors.green)
                            : const StatusChip('Not yet', AdminColors.orange)),
                      ]),
                  ],
                ),
              ),
              const Text(
                'A parent joins automatically the first time they log in to the '
                    'Parent app with the email saved on the student record.',
                style: TextStyle(fontSize: 12, color: AdminColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}