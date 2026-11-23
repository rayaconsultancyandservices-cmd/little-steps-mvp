import 'package:flutter/material.dart';

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
      if (mounted) adminSnack(context, '$e', error: true);
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
      if (mounted) adminSnack(context, '$e', error: true);
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
      if (mounted) adminSnack(context, '$e', error: true);
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
      if (mounted) adminSnack(context, '$err', error: true);
    }
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
      AdminCard(
        title: 'Sent circulars (${s.circulars.length})',
        child: AdminTable(
          emptyText: 'No circulars have been sent yet.',
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
            for (final c in s.circulars)
              DataRow(cells: [
                cellText(c.title, bold: true),
                cellText(s.classNameOf(c.classId)),
                DataCell(StatusChip(c.category, AdminColors.blue)),
                cellText(fmtDate(c.sentAt)),
                cellText('${c.readCount}/${c.families}'),
                cellText(c.needsAck ? '${c.ackCount}/${c.families}' : 'Not required'),
                DataCell(IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 19, color: AdminColors.red),
                  onPressed: () => _deleteCircular(c),
                )),
              ]),
          ],
        ),
      ),
    ];
  }

  List<Widget> _eventsTab(AdminState s) {
    return [
      AdminCard(
        title: 'Events & holidays (${s.events.length})',
        child: AdminTable(
          emptyText: 'No events yet. Use "Add event" to add one.',
          columns: const ['Date', 'Title', 'Type', 'Class', 'Note', ''],
          rows: [
            for (final e in s.events)
              DataRow(cells: [
                cellText(fmtDate(e.date), bold: true),
                cellText(e.title),
                DataCell(StatusChip(e.category, AdminColors.purple)),
                cellText(s.classNameOf(e.classId)),
                cellText(e.note),
                DataCell(IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 19, color: AdminColors.red),
                  onPressed: () => _deleteEvent(e),
                )),
              ]),
          ],
        ),
      ),
    ];
  }
}