import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_widgets.dart';

/// Messages: Teacher ↔ Parent chat conversations (सर्व classes).
/// Admin ला पाहता येतात; अयोग्य message / पूर्ण conversation delete करता येते.
class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  final _search = TextEditingController();
  String _q = '';
  String? _classFilter;
  String? _selected; // studentId
  String? _unreadFilter; // null, 'teacher', or 'parent'

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _time(DateTime? d) {
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${fmtDate(d)} · $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _clear(AdminThread t) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete conversation?',
      message: 'All messages between the teacher and ${t.parentName.isEmpty ? 'the parent' : t.parentName} '
          'about ${t.studentName} will be removed permanently.',
    );
    if (!ok) return;
    try {
      await AdminState.instance.clearThread(t.studentId);
      if (mounted) {
        setState(() => _selected = null);
        adminSnack(context, 'Conversation deleted');
      }
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _deleteMsg(String studentId, AdminMessage m) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete this message?',
      message: m.text,
    );
    if (!ok) return;
    try {
      await AdminState.instance.deleteMessage(studentId, m.id);
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
        final list = s.threads.where((t) {
          if (_classFilter != null && t.classId != _classFilter) return false;
          if (_unreadFilter == 'teacher' && t.teacherUnread == 0) return false;
          if (_unreadFilter == 'parent' && t.parentUnread == 0) return false;
          if (_q.isEmpty) return true;
          return '${t.studentName} ${t.parentName} ${t.lastText}'
              .toLowerCase()
              .contains(_q);
        }).toList()
          ..sort((a, b) => (b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

        AdminThread? current;
        for (final t in s.threads) {
          if (t.studentId == _selected) current = t;
        }

        return AdminPage(
          title: 'Messages',
          subtitle: '${s.threads.length} teacher–parent conversations · '
              '${s.teacherUnreadTotal} unread by teachers',
          actions: [
            AdminSearchField(
              controller: _search,
              hint: 'Search child, parent or message…',
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
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErrorBanner(s.lastError),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MessageMetricCard(
                    label: 'Conversations', value: '${s.threads.length}',
                    icon: Icons.forum_outlined, color: const Color(0xFF3978C5),
                    selected: _unreadFilter == null,
                    onTap: () => setState(() => _unreadFilter = null),
                  ),
                  _MessageMetricCard(
                    label: 'Teacher unread', value: '${s.teacherUnreadTotal}',
                    icon: Icons.mark_chat_unread_outlined, color: AdminColors.orange,
                    selected: _unreadFilter == 'teacher',
                    onTap: () => setState(() => _unreadFilter =
                    _unreadFilter == 'teacher' ? null : 'teacher'),
                  ),
                  _MessageMetricCard(
                    label: 'Parent unread',
                    value: '${s.threads.fold<int>(0, (n, t) => n + t.parentUnread)}',
                    icon: Icons.mark_chat_read_outlined, color: const Color(0xFF159A79),
                    selected: _unreadFilter == 'parent',
                    onTap: () => setState(() => _unreadFilter =
                    _unreadFilter == 'parent' ? null : 'parent'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AdminCard(
                padding: EdgeInsets.zero,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    if (compact) {
                      return SizedBox(
                        height: 680,
                        child: Column(
                          children: [
                            SizedBox(height: 220, child: _threadList(s, list)),
                            const Divider(height: 1, color: AdminColors.border),
                            Expanded(child: _conversation(s, current)),
                          ],
                        ),
                      );
                    }
                    return SizedBox(
                      height: 560,
                      child: Row(
                        children: [
                          SizedBox(width: 320, child: _threadList(s, list)),
                          const VerticalDivider(width: 1, color: AdminColors.border),
                          Expanded(child: _conversation(s, current)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _threadList(AdminState s, List<AdminThread> list) {
    if (list.isEmpty) {
      return const EmptyState('No conversations yet.');
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) =>
      const Divider(height: 1, color: AdminColors.border),
      itemBuilder: (_, i) {
        final t = list[i];
        final sel = t.studentId == _selected;
        return ListTile(
          selected: sel,
          selectedTileColor: const Color(0xFFEFF8F5),
          onTap: () => setState(() => _selected = t.studentId),
          title: Text(
            t.studentName.isEmpty ? s.studentName(t.studentId) : t.studentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          subtitle: Text(
            '${t.parentName.isEmpty ? 'Parent' : t.parentName} · ${s.classNameOf(t.classId)}\n${t.lastText}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          isThreeLine: true,
          trailing: (t.teacherUnread + t.parentUnread) > 0
              ? CircleAvatar(
            radius: 11,
            backgroundColor: AdminColors.orange,
            child: Text(
              '${t.teacherUnread + t.parentUnread}',
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          )
              : null,
        );
      },
    );
  }

  Widget _conversation(AdminState s, AdminThread? t) {
    if (t == null) {
      return const Center(
        child: Text('Select a conversation to read it.',
            style: TextStyle(color: AdminColors.muted)),
      );
    }
    final teacher = s.teacherOfClass(t.classId)?.name ?? 'Teacher';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t.studentName} · ${t.parentName.isEmpty ? 'Parent' : t.parentName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      '${s.classNameOf(t.classId)} · with $teacher · read-only view',
                      style: const TextStyle(
                          fontSize: 11, color: AdminColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete conversation',
                onPressed: () => _clear(t),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AdminColors.red),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AdminColors.border),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('threads')
                .doc(t.studentId)
                .collection('messages')
                .orderBy('at')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(AdminState.errorText(snap.error!),
                      style: const TextStyle(color: AdminColors.red)),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final msgs = [
                for (final d in snap.data!.docs) AdminMessage.fromDoc(d),
              ];
              if (msgs.isEmpty) {
                return const EmptyState('No messages in this conversation.');
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (_, i) => _bubble(t, msgs[i], teacher),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bubble(AdminThread t, AdminMessage m, String teacher) {
    final fromTeacher = m.fromTeacher;
    return Align(
      alignment: fromTeacher ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: fromTeacher ? const Color(0xFFDDF2EC) : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fromTeacher
                        ? teacher
                        : (t.parentName.isEmpty ? 'Parent' : t.parentName),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(m.text, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(_time(m.at),
                      style: const TextStyle(
                          fontSize: 10, color: AdminColors.muted)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete message',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AdminColors.muted),
              onPressed: () => _deleteMsg(t.studentId, m),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact dashboard tile used by the Admin messages screen.
class _MessageMetricCard extends StatelessWidget {
  const _MessageMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(.10) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 172,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? color.withOpacity(.55) : AdminColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
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
                      fontSize: 19, fontWeight: FontWeight.w800, height: 1.1,
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
