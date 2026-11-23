import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Parents: प्रत्येक विद्यार्थ्याचा पालक + त्यांनी Parent app मध्ये login केलं का.
class AdminParentsScreen extends StatefulWidget {
  const AdminParentsScreen({super.key});

  @override
  State<AdminParentsScreen> createState() => _AdminParentsScreenState();
}

class _AdminParentsScreenState extends State<AdminParentsScreen> {
  Future<void> _reset(ChildInfo c) async {
    final mail = c.parentEmail.trim();
    if (mail.isEmpty) {
      adminSnack(context, 'This student has no parent email.', error: true);
      return;
    }
    final err = await AdminState.instance.sendPasswordReset(mail);
    if (!mounted) return;
    if (err != null) {
      adminSnack(context, err, error: true);
    } else {
      adminSnack(context, 'Password reset email sent to $mail');
    }
  }

  Future<void> _unlink(ChildInfo c) async {
    final s = AdminState.instance;
    final p = s.parentUserOf(c);
    if (p == null) return;
    final ok = await adminConfirm(
      context,
      title: 'Unlink ${c.parentName.isEmpty ? p.email : c.parentName}?',
      message: 'The parent login profile is removed. The parent can join again '
          'by logging in with the email saved on the student record.',
      confirmText: 'Unlink',
    );
    if (!ok) return;
    try {
      await s.unlinkParent(p);
      if (mounted) adminSnack(context, 'Parent unlinked');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  final _search = TextEditingController();
  String _q = '';
  int _filter = 0; // 0 all, 1 joined, 2 not yet, 3 missing email

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
        final joined = s.students.where(s.parentJoined).length;
        final notJoined = s.students.length - joined;
        final missingEmail = s.students.where((c) => c.parentEmail.trim().isEmpty).length;
        final list = s.students.where((c) {
          final hasJoined = s.parentJoined(c);
          if (_filter == 1 && !hasJoined) return false;
          if (_filter == 2 && hasJoined) return false;
          if (_filter == 3 && c.parentEmail.trim().isNotEmpty) return false;
          if (_q.isEmpty) return true;
          return '${c.parentName} ${c.parentEmail} ${c.name} ${c.className} ${c.rollNo} ${c.contacts.map((x) => x.phone).join(' ')}'
              .toLowerCase().contains(_q);
        }).toList()
          ..sort((a, b) => a.parentName.toLowerCase().compareTo(b.parentName.toLowerCase()));

        return AdminPage(
          title: 'Parents & Families',
          subtitle: 'Manage family contacts, parent app access and student links.',
          actions: [
            AdminSearchField(
              controller: _search,
              hint: 'Search parent, email, phone or child...',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('All')),
                ButtonSegment(value: 1, label: Text('Joined')),
                ButtonSegment(value: 2, label: Text('Not joined')),
                ButtonSegment(value: 3, label: Text('Missing email')),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorBanner(s.lastError),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ParentMetric(
                    icon: Icons.family_restroom_rounded,
                    label: 'Family records', value: '${s.students.length}',
                    color: AdminColors.primary, selected: _filter == 0,
                    onTap: () => setState(() => _filter = 0),
                  ),
                  _ParentMetric(
                    icon: Icons.verified_user_rounded,
                    label: 'Parent app joined', value: '$joined',
                    color: AdminColors.green, selected: _filter == 1,
                    onTap: () => setState(() => _filter = 1),
                  ),
                  _ParentMetric(
                    icon: Icons.pending_actions_rounded,
                    label: 'Not joined yet', value: '$notJoined',
                    color: AdminColors.orange, selected: _filter == 2,
                    onTap: () => setState(() => _filter = 2),
                  ),
                  _ParentMetric(
                    icon: Icons.mark_email_unread_rounded,
                    label: 'Missing parent email', value: '$missingEmail',
                    color: AdminColors.purple, selected: _filter == 3,
                    onTap: () => setState(() => _filter = 3),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AdminCard(
                title: 'Parent directory',
                trailing: Wrap(
                  spacing: 7,
                  children: [
                    StatusChip('${list.length} shown', AdminColors.blue),
                    StatusChip('$joined joined', AdminColors.green),
                    StatusChip('$notJoined pending', AdminColors.orange),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.manage_accounts_rounded,
                            size: 19, color: AdminColors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Family accounts',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AdminColors.dark)),
                        ),
                        Text('Showing ${list.length} / ${s.students.length}',
                            style: const TextStyle(
                                fontSize: 11, color: AdminColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (s.students.isEmpty)
                      const EmptyState(
                        'No student records are available yet. Parent records appear here when students have been added.',
                        icon: Icons.family_restroom_rounded,
                      )
                    else if (list.isEmpty)
                      const EmptyState(
                        'No parents match this search or account filter.',
                        icon: Icons.search_off_rounded,
                      )
                    else
                      AdminTable(
                        emptyText: 'No parent records found.',
                        columns: const [
                          'Parent / guardian',
                          'Parent email',
                          'Phone',
                          'Student',
                          'Class',
                          'App access',
                          'Account actions',
                        ],
                        rows: [
                          for (final c in list)
                            DataRow(cells: [
                              DataCell(SizedBox(
                                width: 165,
                                child: Row(children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AdminColors.greenLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.person_rounded,
                                        color: AdminColors.primary, size: 19),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      c.parentName.trim().isEmpty
                                          ? 'Not provided'
                                          : c.parentName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AdminColors.dark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ]),
                              )),
                              cellText(c.parentEmail),
                              cellText(c.contacts.isEmpty ? '' : c.contacts.first.phone),
                              cellText(c.name, bold: true),
                              cellText(c.className),
                              DataCell(s.parentJoined(c)
                                  ? const StatusChip('Joined', AdminColors.green)
                                  : const StatusChip('Not joined', AdminColors.orange)),
                              DataCell(PopupMenuButton<String>(
                                tooltip: 'Parent account actions',
                                icon: const Icon(Icons.more_horiz_rounded,
                                    color: AdminColors.muted),
                                onSelected: (v) {
                                  if (v == 'reset') {
                                    _reset(c);
                                  } else if (v == 'unlink') {
                                    _unlink(c);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem<String>(
                                    value: 'reset',
                                    enabled: c.parentEmail.trim().isNotEmpty,
                                    child: const ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.lock_reset_rounded),
                                      title: Text('Send password reset email'),
                                    ),
                                  ),
                                  if (s.parentJoined(c))
                                    const PopupMenuItem<String>(
                                      value: 'unlink',
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.link_off_rounded,
                                            color: AdminColors.red),
                                        title: Text('Unlink parent account'),
                                      ),
                                    ),
                                ],
                              )),
                            ]),
                        ],
                      ),
                  ],
                ),
              ),

              AdminCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AdminColors.primary, size: 19),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Parent app access is detected when a matching parent login profile exists for the student email or student ID. A password reset sends an email; unlinking removes the parent profile document from Firestore. It does not delete the Firebase Authentication account.',
                        style: TextStyle(
                            color: AdminColors.muted,
                            fontSize: 11,
                            height: 1.55),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'A parent can join the Parent app by signing in with the email saved on the student record.',
                style: TextStyle(
                    fontSize: 11, color: AdminColors.muted, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact, clickable KPI used on the parent directory page.
class _ParentMetric extends StatelessWidget {
  const _ParentMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(.09) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 190,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? color.withOpacity(.55) : const Color(0xFFE7EBF0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: const TextStyle(
                      fontSize: 19, height: 1.05, fontWeight: FontWeight.w800,
                      color: AdminColors.dark,
                    )),
                    const SizedBox(height: 3),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AdminColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
