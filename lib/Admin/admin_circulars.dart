import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Circulars & Events: सर्व classes ना (किंवा निवडक classes ना) circular / event पाठवा.
/// पाठवलेलं Parent + Teacher app मध्ये लगेच दिसतं.
class AdminCircularsScreen extends StatefulWidget {
  const AdminCircularsScreen({super.key});

  @override
  State<AdminCircularsScreen> createState() => _AdminCircularsScreenState();
}

class _AdminCircularsScreenState extends State<AdminCircularsScreen> {
  static const _categories = ['Notice', 'Holiday', 'Meeting', 'Event', 'Celebration'];

  int _tab = 0; // 0 circulars, 1 events
  bool _busy = false;
  String _circularFilter = 'All';
  String _eventFilter = 'All';

  List<AdminCircular> _filteredCirculars(AdminState s) {
    final items = [...s.circulars];
    switch (_circularFilter) {
      case 'Important':
        return items.where((c) => c.important).toList();
      case 'Unread':
        return items.where((c) => c.readCount < c.families).toList();
      case 'Pending ack':
        return items.where((c) => c.needsAck && c.ackCount < c.families).toList();
      default:
        return items;
    }
  }

  List<AdminEvent> _filteredEvents(AdminState s) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final items = [...s.events];
    if (_eventFilter == 'Upcoming') {
      return items.where((e) => !e.date.isBefore(startOfToday)).toList();
    }
    if (_eventFilter == 'Past') {
      return items.where((e) => e.date.isBefore(startOfToday)).toList();
    }
    return items;
  }

  // ---- circular form ----
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _category = 'Notice';
  bool _important = false;
  bool _needsAck = false;
  DateTime? _eventDate;
  bool _allClasses = true;
  final Set<String> _chosen = {};

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  List<String> _targetClassIds(AdminState s) =>
      _allClasses ? s.classes.map((c) => c.id).toList() : _chosen.toList();

  String _audienceLabel(AdminState s) {
    if (_allClasses) return 'Whole school';
    return _chosen.map(s.classNameOf).join(', ');
  }

  Future<void> _send() async {
    final s = AdminState.instance;
    if (!_formKey.currentState!.validate()) return;
    final ids = _targetClassIds(s);
    if (ids.isEmpty) {
      adminSnack(
        context,
        s.classes.isEmpty ? 'Create a class first.' : 'Select at least one class.',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await s.sendCircular(
        classIds: ids,
        title: _title.text,
        message: _message.text,
        category: _category,
        audienceLabel: _audienceLabel(s),
        important: _important,
        needsAck: _needsAck,
        eventDate: _eventDate,
      );
      if (!mounted) return;
      _title.clear();
      _message.clear();
      setState(() {
        _important = false;
        _needsAck = false;
        _eventDate = null;
        _category = 'Notice';
      });
      adminSnack(context, 'Circular sent to ${ids.length} class(es)');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _eventDate = d);
  }

  /// Circular चा पूर्ण मजकूर + कोणाच्या parents नी वाचलं / नाही वाचलं.
  Future<void> _view(AdminCircular c) async {
    final s = AdminState.instance;
    final kids = s.studentsOfClass(c.classId);
    final notRead = kids.where((k) => !c.readBy.contains(k.id)).toList();
    final notAcked = c.needsAck
        ? kids.where((k) => !c.ackedBy.contains(k.id)).toList()
        : <ChildInfo>[];

    String names(List<ChildInfo> l) =>
        l.isEmpty ? 'Everyone' : l.map((k) => k.name).join(', ');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(c.title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusChip(c.category, AdminColors.blue),
                    if (c.important) const StatusChip('Important', AdminColors.red),
                    if (c.needsAck)
                      const StatusChip('Needs acknowledgement', AdminColors.orange),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${s.classNameOf(c.classId)} · Sent ${fmtDate(c.sentAt)}'
                      '${c.eventDate == null ? '' : ' · Event on ${fmtDate(c.eventDate)}'}',
                  style: const TextStyle(fontSize: 12, color: AdminColors.muted),
                ),
                const SizedBox(height: 12),
                Text(c.message.isEmpty ? '(no message)' : c.message),
                const SizedBox(height: 16),
                Text('Read ${c.readCount}/${kids.length}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  notRead.isEmpty
                      ? 'All parents have read this.'
                      : 'Not read yet: ${names(notRead)}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (c.needsAck) ...[
                  const SizedBox(height: 12),
                  Text('Acknowledged ${c.ackCount}/${kids.length}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    notAcked.isEmpty
                        ? 'All parents have acknowledged.'
                        : 'Pending: ${names(notAcked)}',
                    style: const TextStyle(fontSize: 12),
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

  Future<void> _editCircular(AdminCircular c) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(text: c.title);
    final message = TextEditingController(text: c.message);
    String category = _categories.contains(c.category) ? c.category : 'Notice';
    bool important = c.important;
    bool needsAck = c.needsAck;
    DateTime? eventDate = c.eventDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text('Edit circular · ${AdminState.instance.classNameOf(c.classId)}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    dialogField(title, 'Title', required: true),
                    dialogField(message, 'Message', required: true, maxLines: 4),
                    AdminDropdown<String>(
                      label: 'Category',
                      width: 480,
                      value: category,
                      items: [
                        for (final x in _categories)
                          DropdownMenuItem(value: x, child: Text(x)),
                      ],
                      onChanged: (v) => setD(() => category = v ?? category),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: eventDate ?? now,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 2),
                            );
                            if (d != null) setD(() => eventDate = d);
                          },
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(eventDate == null
                              ? 'Event date (optional)'
                              : fmtDate(eventDate)),
                        ),
                        if (eventDate != null)
                          IconButton(
                            tooltip: 'Clear date',
                            onPressed: () => setD(() => eventDate = null),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        FilterChip(
                          label: const Text('Important'),
                          selected: important,
                          onSelected: (v) => setD(() => important = v),
                        ),
                        FilterChip(
                          label: const Text('Needs acknowledgement'),
                          selected: needsAck,
                          onSelected: (v) => setD(() => needsAck = v),
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
      await AdminState.instance.updateCircular(
        c,
        title: title.text,
        message: message.text,
        category: category,
        important: important,
        needsAck: needsAck,
        eventDate: eventDate,
      );
      if (mounted) adminSnack(context, 'Circular updated');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _editEvent(AdminEvent e) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(text: e.title);
    final note = TextEditingController(text: e.note);
    String category = _categories.contains(e.category) ? e.category : 'Event';
    DateTime date = e.date;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text('Edit event · ${AdminState.instance.classNameOf(e.classId)}'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    dialogField(title, 'Title', required: true),
                    dialogField(note, 'Note (optional)', maxLines: 2),
                    Row(
                      children: [
                        Expanded(
                          child: AdminDropdown<String>(
                            label: 'Type',
                            value: category,
                            width: double.infinity,
                            items: [
                              for (final x in _categories)
                                DropdownMenuItem(value: x, child: Text(x)),
                            ],
                            onChanged: (v) => setD(() => category = v ?? category),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: date,
                              firstDate: DateTime(now.year - 2),
                              lastDate: DateTime(now.year + 3),
                            );
                            if (d != null) setD(() => date = d);
                          },
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(fmtDate(date)),
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
      await AdminState.instance.updateEvent(
        e,
        title: title.text,
        category: category,
        date: date,
        note: note.text,
      );
      if (mounted) adminSnack(context, 'Event updated');
    } catch (err) {
      if (mounted) adminSnack(context, AdminState.errorText(err), error: true);
    }
  }

  Future<void> _deleteCircular(AdminCircular c) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete circular?',
      message: '"${c.title}" will be removed for ${AdminState.instance.classNameOf(c.classId)}.',
    );
    if (!ok) return;
    try {
      await AdminState.instance.deleteCircular(c);
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  // ------------------------------------------------------------------
  // EVENTS
  // ------------------------------------------------------------------
  Future<void> _addEvent() async {
    final s = AdminState.instance;
    if (s.classes.isEmpty) {
      adminSnack(context, 'Create a class first.', error: true);
      return;
    }
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final note = TextEditingController();
    String category = 'Event';
    DateTime? date;
    bool all = true;
    final chosen = <String>{};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Add event / holiday'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    dialogField(title, 'Title', required: true),
                    dialogField(note, 'Note (optional)', maxLines: 2),
                    Row(
                      children: [
                        Expanded(
                          child: AdminDropdown<String>(
                            label: 'Type',
                            value: category,
                            width: double.infinity,
                            items: [
                              for (final c in _categories)
                                DropdownMenuItem(value: c, child: Text(c)),
                            ],
                            onChanged: (v) => setD(() => category = v ?? category),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: date ?? now,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 2),
                            );
                            if (d != null) setD(() => date = d);
                          },
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(date == null ? 'Pick date' : fmtDate(date)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('All classes'),
                      value: all,
                      onChanged: (v) => setD(() => all = v),
                    ),
                    if (!all)
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final c in s.classes)
                            FilterChip(
                              label: Text(c.className),
                              selected: chosen.contains(c.id),
                              onSelected: (v) => setD(
                                    () => v ? chosen.add(c.id) : chosen.remove(c.id),
                              ),
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
                if (!formKey.currentState!.validate()) return;
                if (date == null || (!all && chosen.isEmpty)) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || date == null) return;
    try {
      await s.addEvent(
        classIds: all ? s.classes.map((c) => c.id).toList() : chosen.toList(),
        title: title.text,
        category: category,
        date: date!,
        note: note.text,
      );
      if (mounted) adminSnack(context, 'Event added');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _deleteEvent(AdminEvent e) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete event?',
      message: '"${e.title}" will be removed for ${AdminState.instance.classNameOf(e.classId)}.',
    );
    if (!ok) return;
    try {
      await AdminState.instance.deleteEvent(e);
    } catch (err) {
      if (mounted) adminSnack(context, AdminState.errorText(err), error: true);
    }
  }

  Widget _overviewMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 168,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : const Color(0xFFE7EAF0)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 3),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AdminColors.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        return AdminPage(
          title: 'Circulars & Events',
          subtitle: 'Send announcements and manage the school calendar',
          actions: [
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Circulars')),
                ButtonSegment(value: 1, label: Text('Events & holidays')),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
            if (_tab == 1)
              FilledButton.icon(
                style: adminPrimaryButton(),
                onPressed: _addEvent,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add event'),
              ),
          ],
          child: Column(
            children: [
              ErrorBanner(s.lastError),
              if (_tab == 0) ..._circularTab(s) else ..._eventsTab(s),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _circularTab(AdminState s) {
    return [
      AdminCard(
        title: 'New circular',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dialogField(_title, 'Title', required: true),
              dialogField(_message, 'Message', required: true, maxLines: 4),
              Wrap(
                spacing: 14,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AdminDropdown<String>(
                    label: 'Category',
                    width: 200,
                    value: _category,
                    items: [
                      for (final c in _categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickEventDate,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(
                      _eventDate == null
                          ? 'Event date (optional)'
                          : fmtDate(_eventDate),
                    ),
                  ),
                  if (_eventDate != null)
                    IconButton(
                      tooltip: 'Clear date',
                      onPressed: () => setState(() => _eventDate = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  FilterChip(
                    label: const Text('Important'),
                    selected: _important,
                    onSelected: (v) => setState(() => _important = v),
                  ),
                  FilterChip(
                    label: const Text('Needs acknowledgement'),
                    selected: _needsAck,
                    onSelected: (v) => setState(() => _needsAck = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Send to',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Whole school'),
                    selected: _allClasses,
                    onSelected: (_) => setState(() => _allClasses = true),
                  ),
                  ChoiceChip(
                    label: const Text('Choose classes'),
                    selected: !_allClasses,
                    onSelected: (_) => setState(() => _allClasses = false),
                  ),
                  if (!_allClasses)
                    for (final c in s.classes)
                      FilterChip(
                        label: Text(c.className),
                        selected: _chosen.contains(c.id),
                        onSelected: (v) => setState(
                              () => v ? _chosen.add(c.id) : _chosen.remove(c.id),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: adminPrimaryButton(),
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  'Send to ${_targetClassIds(s).fold<int>(0, (n, id) => n + s.studentsOfClass(id).length)} families',
                ),
              ),
            ],
          ),
        ),
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _overviewMetric(label: 'All circulars', value: '${s.circulars.length}', icon: Icons.campaign_outlined, color: AdminColors.blue, selected: _circularFilter == 'All', onTap: () => setState(() => _circularFilter = 'All')),
          _overviewMetric(label: 'Important', value: '${s.circulars.where((c) => c.important).length}', icon: Icons.priority_high_rounded, color: AdminColors.red, selected: _circularFilter == 'Important', onTap: () => setState(() => _circularFilter = 'Important')),
          _overviewMetric(label: 'Unread', value: '${s.circulars.where((c) => c.readCount < c.families).length}', icon: Icons.mark_email_unread_outlined, color: AdminColors.orange, selected: _circularFilter == 'Unread', onTap: () => setState(() => _circularFilter = 'Unread')),
          _overviewMetric(label: 'Ack pending', value: '${s.circulars.where((c) => c.needsAck && c.ackCount < c.families).length}', icon: Icons.pending_actions_rounded, color: AdminColors.purple, selected: _circularFilter == 'Pending ack', onTap: () => setState(() => _circularFilter = 'Pending ack')),
        ],
      ),
      const SizedBox(height: 14),
      AdminCard(
        title: 'Sent circulars (${_filteredCirculars(s).length})',
        child: AdminTable(
          emptyText: 'No circulars match this filter.',
          columns: const [
            'Title',
            'Class',
            'Category',
            'Sent',
            'Read',
            'Acknowledged',
            '',
          ],
          rows: [
            for (final c in _filteredCirculars(s))
              DataRow(cells: [
                cellText(c.title, bold: true),
                cellText(s.classNameOf(c.classId)),
                DataCell(StatusChip(c.category, AdminColors.blue)),
                cellText(fmtDate(c.sentAt)),
                cellText('${c.readCount}/${c.families}'),
                cellText(c.needsAck ? '${c.ackCount}/${c.families}' : 'Not required'),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'View',
                      icon: const Icon(Icons.visibility_outlined, size: 19),
                      onPressed: () => _view(c),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      onPressed: () => _editCircular(c),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 19, color: AdminColors.red),
                      onPressed: () => _deleteCircular(c),
                    ),
                  ],
                )),
              ]),
          ],
        ),
      ),
    ];
  }

  List<Widget> _eventsTab(AdminState s) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final upcomingCount = s.events.where((e) => !e.date.isBefore(startOfToday)).length;
    final pastCount = s.events.length - upcomingCount;
    return [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _overviewMetric(label: 'All events', value: '${s.events.length}', icon: Icons.event_note_rounded, color: AdminColors.blue, selected: _eventFilter == 'All', onTap: () => setState(() => _eventFilter = 'All')),
          _overviewMetric(label: 'Upcoming', value: '$upcomingCount', icon: Icons.upcoming_rounded, color: AdminColors.green, selected: _eventFilter == 'Upcoming', onTap: () => setState(() => _eventFilter = 'Upcoming')),
          _overviewMetric(label: 'Past events', value: '$pastCount', icon: Icons.history_rounded, color: AdminColors.orange, selected: _eventFilter == 'Past', onTap: () => setState(() => _eventFilter = 'Past')),
        ],
      ),
      const SizedBox(height: 14),
      AdminCard(
        title: 'Events & holidays (${_filteredEvents(s).length})',
        child: AdminTable(
          emptyText: 'No events match this filter.',
          columns: const ['Date', 'Title', 'Type', 'Class', 'Note', ''],
          rows: [
            for (final e in _filteredEvents(s))
              DataRow(cells: [
                cellText(fmtDate(e.date), bold: true),
                cellText(e.title),
                DataCell(StatusChip(e.category, AdminColors.purple)),
                cellText(s.classNameOf(e.classId)),
                cellText(e.note),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      onPressed: () => _editEvent(e),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 19, color: AdminColors.red),
                      onPressed: () => _deleteEvent(e),
                    ),
                  ],
                )),
              ]),
          ],
        ),
      ),
    ];
  }
}