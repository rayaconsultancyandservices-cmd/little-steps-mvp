import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/page_app_bar.dart';

/// Teacher चा "Events & Holidays" screen (नवीन).
/// इथे जोडलेले events Parent app च्या Calendar मध्ये लगेच दिसतात.
/// Home च्या "Events" tile वरून उघडतो.
class TeacherEventsScreen extends StatefulWidget {
  const TeacherEventsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<TeacherEventsScreen> createState() => _TeacherEventsScreenState();
}

class _TeacherEventsScreenState extends State<TeacherEventsScreen> {
  static const Color primary = Color(0xFF168C80);
  static const Color dark = Color(0xFF183B45);
  static const Color muted = Color(0xFF82918D);
  static const Color red = Color(0xFFE36B61);

  // Parent च्या Calendar मधील categories सारख्याच.
  static const List<String> categories = [
    'Holiday',
    'Meeting',
    'Event',
    'Celebration',
  ];

  static const Map<String, IconData> categoryIcons = {
    'Holiday': Icons.beach_access_rounded,
    'Meeting': Icons.groups_rounded,
    'Event': Icons.event_rounded,
    'Celebration': Icons.celebration_rounded,
  };

  static const Map<String, Color> categoryColors = {
    'Holiday': Color(0xFFE39A3A),
    'Meeting': Color(0xFF4786C7),
    'Event': Color(0xFF168C80),
    'Celebration': Color(0xFFE47778),
  };

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  // ---------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------
  Future<void> _openForm({SchoolEvent? existing}) async {
    final result = await showModalBottomSheet<SchoolEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EventSheet(existing: existing, categories: categories),
    );
    if (result == null || !mounted) return;

    try {
      if (existing == null) {
        await AppState.instance.addEvent(result);
        if (!mounted) return;
        _snack('Event added. Parents can see it in their calendar.');
      } else {
        await AppState.instance.updateEvent(result);
        if (!mounted) return;
        _snack('Event updated.');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Could not save event: $e');
    }
  }

  Future<void> _confirmDelete(SchoolEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete event?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '"${e.title}" will be removed from the Parent calendar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AppState.instance.deleteEvent(e.id);
    } catch (err) {
      if (!mounted) return;
      _snack('Could not delete event: $err');
    }
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: buildPageAppBar(
        title: 'Events & Holidays',
        subtitle: 'Shown in the Parent app calendar',
        onBack: widget.onBack,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add event',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final all = AppState.instance.classEvents;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          final upcoming = all.where((e) => !e.date.isBefore(today)).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          final past = all.where((e) => e.date.isBefore(today)).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (all.isEmpty) return _buildEmpty();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Upcoming (${upcoming.length})'),
                      const SizedBox(height: 8),
                      if (upcoming.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                          child: Text(
                            'No upcoming events.',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        )
                      else
                        for (final e in upcoming) _eventCard(e, past: false),
                      if (past.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _sectionTitle('Past (${past.length})'),
                        const SizedBox(height: 8),
                        for (final e in past) _eventCard(e, past: true),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F5F0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.event_rounded, size: 34, color: primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No events yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: dark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "Add event" to add a holiday, meeting or celebration.\n'
                  'Parents will see it in their calendar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.5, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: dark,
      ),
    ),
  );

  Widget _eventCard(SchoolEvent e, {required bool past}) {
    final color = categoryColors[e.category] ?? primary;
    final icon = categoryIcons[e.category] ?? Icons.event_rounded;

    return Opacity(
      opacity: past ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    AppState.monthShort(e.date.month).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    '${e.date.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(icon, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(
                        e.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${AppState.dateLabel(e.date)} ${e.date.year}',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                  if (e.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      e.note,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: muted),
              onSelected: (v) {
                if (v == 'edit') _openForm(existing: e);
                if (v == 'delete') _confirmDelete(e);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Event जोडण्याचा / बदलण्याचा bottom sheet
// =====================================================================
class _EventSheet extends StatefulWidget {
  const _EventSheet({required this.existing, required this.categories});

  final SchoolEvent? existing;
  final List<String> categories;

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  static const Color dark = Color(0xFF183B45);
  static const Color primary = Color(0xFF168C80);
  static const Color muted = Color(0xFF84918D);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
  TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _note =
  TextEditingController(text: widget.existing?.note ?? '');
  late String _category = widget.categories.contains(widget.existing?.category)
      ? widget.existing!.category
      : 'Event';
  late DateTime _date = widget.existing == null
      ? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
      : DateTime(widget.existing!.date.year, widget.existing!.date.month,
      widget.existing!.date.day);

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF4F9F8),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD4E5E1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD4E5E1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primary, width: 1.4),
    ),
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    var first = DateTime(now.year - 1);
    if (_date.isBefore(first)) first = _date;
    var last = DateTime(now.year + 2, 12, 31);
    if (_date.isAfter(last)) last = _date;

    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: last,
    );
    if (d != null) setState(() => _date = d);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      SchoolEvent(
        id: widget.existing?.id ?? '',
        date: _date,
        title: _title.text.trim(),
        category: _category,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDE5E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEdit ? 'Edit event' : 'Add event',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Parents of your class will see this in their calendar.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Title', hint: 'e.g. Diwali Holiday'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final c in widget.categories)
                      ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        showCheckmark: false,
                        selectedColor: primary,
                        backgroundColor: const Color(0xFFE4F3EF),
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _category == c ? Colors.white : primary,
                        ),
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _dec('Date'),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 18, color: primary),
                        const SizedBox(width: 8),
                        Text(
                          '${_date.day} ${AppState.monthShort(_date.month)} ${_date.year}',
                          style: const TextStyle(fontSize: 14, color: dark),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Note (optional)',
                      hint: 'Time, place or anything parents should know'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isEdit ? 'Save changes' : 'Add event',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}