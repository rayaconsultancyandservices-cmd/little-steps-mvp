import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/app_button.dart';
import '../widgets/page_app_bar.dart';

/// Extra details for a sent circular (the shared model does not store these).
class _SentExtra {
  const _SentExtra({
    this.important = false,
    this.needsAck = false,
    this.scheduledFor,
  });

  final bool important;
  final bool needsAck;
  final DateTime? scheduledFor;
}

class _Draft {
  _Draft({
    required this.title,
    required this.message,
    required this.category,
    required this.audience,
    required this.chosen,
    required this.eventDate,
    required this.attachment,
    required this.important,
    required this.needsAck,
    required this.scheduledFor,
    required this.savedAt,
  });

  final String title;
  final String message;
  final String category;
  final int audience;
  final Set<String> chosen;
  final DateTime? eventDate;
  final String? attachment;
  final bool important;
  final bool needsAck;
  final DateTime? scheduledFor;
  final DateTime savedAt;
}

class _Template {
  const _Template(this.label, this.icon, this.category, this.title, this.message);

  final String label;
  final IconData icon;
  final String category;
  final String title;
  final String message;
}

class CircularScreen extends StatefulWidget {
  const CircularScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<CircularScreen> createState() => _CircularScreenState();
}

class _CircularScreenState extends State<CircularScreen> {
  static const Color _primary = Color(0xFF2F8877);
  static const Color _dark = Color(0xFF24313D);
  static const Color _muted = Color(0xFF7B8794);
  static const Color _danger = Color(0xFFE5484D);

  static const Map<String, int> _classFamilies = {
    'Nursery A': 22,
    'Nursery B': 21,
    'LKG': 22,
    'UKG': 21,
  };

  static const List<String> _categories = [
    'Notice',
    'Holiday',
    'Meeting',
    'Event',
    'Celebration',
  ];

  static const Map<String, IconData> _categoryIcons = {
    'Notice': Icons.campaign_rounded,
    'Holiday': Icons.beach_access_rounded,
    'Meeting': Icons.groups_rounded,
    'Event': Icons.event_rounded,
    'Celebration': Icons.celebration_rounded,
  };

  static const Map<String, Color> _categoryColors = {
    'Notice': Color(0xFF4786C7),
    'Holiday': Color(0xFFE39A3A),
    'Meeting': Color(0xFF8066C8),
    'Event': Color(0xFF2F8877),
    'Celebration': Color(0xFFE47778),
  };

  static const List<_Template> _templates = [
    _Template(
      'Holiday',
      Icons.beach_access_rounded,
      'Holiday',
      'School Holiday Notice',
      'Dear Parents, the school will remain closed on the mentioned date. '
          'Classes will resume on the next working day. Thank you.',
    ),
    _Template(
      'PTM Reminder',
      Icons.groups_rounded,
      'Meeting',
      'Parent–Teacher Meeting',
      'Dear Parents, you are invited to the Parent–Teacher Meeting. '
          'Please attend and discuss your child’s progress with us.',
    ),
    _Template(
      'Fee Reminder',
      Icons.payments_outlined,
      'Notice',
      'Fee Payment Reminder',
      'Dear Parents, this is a gentle reminder to pay the pending school '
          'fees before the due date. Kindly ignore if already paid.',
    ),
    _Template(
      'Annual Day',
      Icons.celebration_rounded,
      'Event',
      'Annual Day Celebration',
      'Dear Parents, our Annual Day will be celebrated with great joy. '
          'Please send your child in the prescribed costume on time.',
    ),
    _Template(
      'Weather Alert',
      Icons.thunderstorm_outlined,
      'Notice',
      'Weather Advisory',
      'Dear Parents, due to heavy rain, please take care while dropping '
          'and picking up your child. Carry a raincoat or umbrella.',
    ),
  ];

  int _audience = 0;
  final Set<String> _chosen = {};

  String _category = 'Notice';
  DateTime? _eventDate;
  String? _attachment;

  // Delivery options
  bool _important = false;
  bool _needsAck = false;
  bool _scheduleLater = false;
  DateTime? _scheduledFor;

  final TextEditingController _title = TextEditingController();
  final TextEditingController _message = TextEditingController();

  final List<_Draft> _drafts = [];
  final Map<CircularRecord, _SentExtra> _extras = {};

  bool _isSending = false;

  int get _families {
    switch (_audience) {
      case 0:
        return AppState.instance.totalFamilies;
      case 1:
        return _classFamilies['Nursery A']!;
      default:
        return _chosen.fold<int>(
          0,
              (sum, name) => sum + (_classFamilies[name] ?? 0),
        );
    }
  }

  String get _audienceLabel {
    switch (_audience) {
      case 0:
        return 'Whole school';
      case 1:
        return 'Nursery A';
      default:
        return _chosen.join(', ');
    }
  }

  String _dateTimeLabel(DateTime d) =>
      '${AppState.dateLabel(d)}, ${AppState.timeLabel(d)}';

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _showMessage(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          action: action,
        ),
      );
  }

  // ---------------------------------------------------------------
  // PICKERS
  // ---------------------------------------------------------------
  Future<void> _pickClasses() async {
    final temp = Set<String>.of(_chosen);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 4,
                        width: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 19),
                    const Text(
                      'Choose Classes',
                      style: TextStyle(
                        color: _dark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Select one or more classes to receive this circular.',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 14),
                    for (final entry in _classFamilies.entries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: temp.contains(entry.key),
                        activeColor: _primary,
                        title: Text(
                          entry.key,
                          style: const TextStyle(
                            color: _dark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${entry.value} families',
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                        onChanged: (value) {
                          setSheet(() {
                            if (value == true) {
                              temp.add(entry.key);
                            } else {
                              temp.remove(entry.key);
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 10),
                    AppButton(
                      title: temp.isEmpty
                          ? 'Choose at least one class'
                          : 'Done · ${temp.length} selected',
                      icon: Icons.check_rounded,
                      onPressed:
                      temp.isEmpty ? null : () => Navigator.pop(ctx, temp),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _chosen
        ..clear()
        ..addAll(result);
      _audience = 2;
    });
  }

  ThemeData _pickerTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: _dark,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Select circular date',
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );

    if (picked != null && mounted) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      helpText: 'Send on',
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledFor != null
          ? TimeOfDay.fromDateTime(_scheduledFor!)
          : const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Send at',
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );

    if (time == null || !mounted) return;

    final result =
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (result.isBefore(DateTime.now())) {
      _showMessage('Please choose a time in the future.');
      return;
    }

    setState(() => _scheduledFor = result);
  }

  // Demo attachment picker
  void _attach() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Attachment',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: _attachmentIcon(
                    Icons.picture_as_pdf_rounded,
                    const Color(0xFFE16B61),
                  ),
                  title: const Text('Attach PDF'),
                  subtitle: const Text('PDF document · Demo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _attachment = 'circular.pdf');
                  },
                ),
                ListTile(
                  leading: _attachmentIcon(
                    Icons.image_rounded,
                    const Color(0xFF4786C7),
                  ),
                  title: const Text('Attach Image'),
                  subtitle: const Text('Image file · Demo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _attachment = 'notice.jpg');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentIcon(IconData icon, Color color) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }

  // ---------------------------------------------------------------
  // TEMPLATES / DRAFTS / REUSE
  // ---------------------------------------------------------------
  void _applyTemplate(_Template t) {
    setState(() {
      _category = t.category;
      if (t.category == 'Notice') _eventDate = null;
      _title.text = t.title;
      _message.text = t.message;
    });
  }

  void _resetForm() {
    _title.clear();
    _message.clear();
    _category = 'Notice';
    _eventDate = null;
    _attachment = null;
    _audience = 0;
    _chosen.clear();
    _important = false;
    _needsAck = false;
    _scheduleLater = false;
    _scheduledFor = null;
  }

  void _saveDraft() {
    if (_title.text.trim().isEmpty && _message.text.trim().isEmpty) {
      _showMessage('Write a title or message to save a draft.');
      return;
    }

    setState(() {
      _drafts.insert(
        0,
        _Draft(
          title: _title.text.trim(),
          message: _message.text.trim(),
          category: _category,
          audience: _audience,
          chosen: Set<String>.of(_chosen),
          eventDate: _eventDate,
          attachment: _attachment,
          important: _important,
          needsAck: _needsAck,
          scheduledFor: _scheduleLater ? _scheduledFor : null,
          savedAt: DateTime.now(),
        ),
      );
      _resetForm();
    });

    _showMessage('Draft saved.');
  }

  void _loadDraft(_Draft d) {
    setState(() {
      _drafts.remove(d);
      _title.text = d.title;
      _message.text = d.message;
      _category = d.category;
      _audience = d.audience;
      _chosen
        ..clear()
        ..addAll(d.chosen);
      _eventDate = d.eventDate;
      _attachment = d.attachment;
      _important = d.important;
      _needsAck = d.needsAck;
      _scheduleLater = d.scheduledFor != null;
      _scheduledFor = d.scheduledFor;
    });

    _showMessage('Draft loaded. You can edit and send it.');
  }

  void _deleteDraft(_Draft d) {
    final index = _drafts.indexOf(d);

    setState(() => _drafts.remove(d));

    _showMessage(
      'Draft deleted.',
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          setState(() => _drafts.insert(index.clamp(0, _drafts.length), d));
        },
      ),
    );
  }

  void _reuse(CircularRecord record) {
    setState(() {
      _title.text = record.title;
      _category = record.category;
      _eventDate = null;
      _attachment = record.attachment;
    });

    _showMessage('Circular copied. Add the message and send again.');
  }

  void _openHistoryDetails(CircularRecord record) {
    final color = _categoryColors[record.category] ?? _primary;
    final extra = _extras[record];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDE5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _categoryBadge(record.category),
                    if (extra?.important == true) ...[
                      const SizedBox(width: 7),
                      _pill('Important', _danger),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  record.title,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _previewInfo(Icons.groups_outlined, 'Audience', record.audience),
                const SizedBox(height: 9),
                _previewInfo(
                  Icons.family_restroom_rounded,
                  'Families',
                  '${record.families}',
                ),
                const SizedBox(height: 9),
                _previewInfo(
                  Icons.schedule_rounded,
                  extra?.scheduledFor != null ? 'Scheduled' : 'Sent',
                  _dateTimeLabel(extra?.scheduledFor ?? record.sentAt),
                ),
                if (record.eventDate != null) ...[
                  const SizedBox(height: 9),
                  _previewInfo(
                    Icons.calendar_month_rounded,
                    'Date',
                    AppState.shortDate(record.eventDate!),
                  ),
                ],
                if (extra?.needsAck == true) ...[
                  const SizedBox(height: 9),
                  _previewInfo(
                    Icons.fact_check_outlined,
                    'Acknowledgement',
                    'Required from parents',
                  ),
                ],
                if (record.attachment != null) ...[
                  const SizedBox(height: 9),
                  _previewInfo(
                    Icons.attach_file_rounded,
                    'Attachment',
                    record.attachment!,
                  ),
                ],
                const SizedBox(height: 18),
                AppButton(
                  title: 'Reuse this circular',
                  icon: Icons.copy_all_rounded,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _reuse(record);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // VALIDATION / SEND / PREVIEW
  // ---------------------------------------------------------------
  String _validationError() {
    if (_title.text.trim().isEmpty) {
      return 'Please enter a circular title.';
    }

    if (_message.text.trim().isEmpty) {
      return 'Please enter the circular message.';
    }

    if (_audience == 2 && _chosen.isEmpty) {
      return 'Please choose at least one class.';
    }

    if (_category != 'Notice' && _eventDate == null) {
      return 'Please select the date for this $_category.';
    }

    if (_scheduleLater && _scheduledFor == null) {
      return 'Please choose when to send this circular.';
    }

    if (_scheduleLater &&
        _scheduledFor != null &&
        _scheduledFor!.isBefore(DateTime.now())) {
      return 'The scheduled time has already passed.';
    }

    return '';
  }

  Future<void> _send() async {
    if (_isSending) return;

    final error = _validationError();

    if (error.isNotEmpty) {
      _showMessage(error);
      return;
    }

    final families = _families;
    final title = _title.text.trim();
    final category = _category;
    final audience = _audienceLabel;
    final scheduled = _scheduleLater ? _scheduledFor : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21),
          ),
          title: Text(
            scheduled != null ? 'Confirm Schedule' : 'Confirm Circular',
            style: const TextStyle(
              color: _dark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _dark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Category: $category\n'
                    'Audience: $audience\n'
                    'Families: $families'
                    '${_eventDate == null ? '' : '\nDate: ${AppState.shortDate(_eventDate!)}'}'
                    '${scheduled == null ? '' : '\nSend on: ${_dateTimeLabel(scheduled)}'}'
                    '${_important ? '\nMarked as important' : ''}'
                    '${_needsAck ? '\nAcknowledgement required' : ''}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please check the audience and details before confirming.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              child: Text(scheduled != null ? 'Confirm Schedule' : 'Confirm Send'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    // AppState stores circular metadata locally.
    // The message is not stored by the current model.
    final record = CircularRecord(
      title: title,
      audience: audience,
      category: category,
      families: families,
      sentAt: DateTime.now(),
      eventDate: _eventDate,
      attachment: _attachment,
    );

    _extras[record] = _SentExtra(
      important: _important,
      needsAck: _needsAck,
      scheduledFor: scheduled,
    );

    AppState.instance.addCircular(record);

    setState(() {
      _resetForm();
      _isSending = false;
    });

    _showMessage(
      scheduled != null
          ? 'Circular scheduled for ${_dateTimeLabel(scheduled)}.'
          : 'Circular saved in demo history for $families families.',
    );
  }

  Future<void> _preview() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      _showMessage('Enter title and message to preview.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.all(19),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Circular Preview',
                          style: TextStyle(
                            color: _dark,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _categoryBadge(_category),
                      if (_important) ...[
                        const SizedBox(width: 7),
                        _pill('Important', _danger),
                      ],
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _title.text.trim(),
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _message.text.trim(),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const Divider(height: 25),
                  _previewInfo(
                    Icons.groups_outlined,
                    'Audience',
                    _audienceLabel.isEmpty ? '—' : _audienceLabel,
                  ),
                  const SizedBox(height: 10),
                  _previewInfo(
                    Icons.family_restroom_rounded,
                    'Families',
                    '$_families',
                  ),
                  if (_eventDate != null) ...[
                    const SizedBox(height: 10),
                    _previewInfo(
                      Icons.calendar_month_rounded,
                      'Date',
                      AppState.shortDate(_eventDate!),
                    ),
                  ],
                  if (_scheduleLater && _scheduledFor != null) ...[
                    const SizedBox(height: 10),
                    _previewInfo(
                      Icons.schedule_send_rounded,
                      'Send on',
                      _dateTimeLabel(_scheduledFor!),
                    ),
                  ],
                  if (_needsAck) ...[
                    const SizedBox(height: 10),
                    _previewInfo(
                      Icons.fact_check_outlined,
                      'Acknowledgement',
                      'Required',
                    ),
                  ],
                  if (_attachment != null) ...[
                    const SizedBox(height: 10),
                    _previewInfo(
                      Icons.attach_file_rounded,
                      'Attachment',
                      _attachment!,
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Close Preview'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _previewInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: _primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _dark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final history = AppState.instance.circulars;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: buildPageAppBar(
        title: 'New Circular',
        subtitle: 'Announcements for parents',
        onBack: widget.onBack,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // AUDIENCE
          _sectionTitle(
            'Send Circular To',
            'Choose who should receive this message',
          ),

          const SizedBox(height: 11),

          Column(
            children: [
              _audienceOption(
                title: 'Whole School',
                subtitle: 'All ${AppState.instance.totalFamilies} families',
                icon: Icons.apartment_rounded,
                selected: _audience == 0,
                onTap: () => setState(() => _audience = 0),
              ),
              const SizedBox(height: 9),
              _audienceOption(
                title: 'Nursery A',
                subtitle: '${_classFamilies['Nursery A']} families',
                icon: Icons.child_care_rounded,
                selected: _audience == 1,
                onTap: () => setState(() => _audience = 1),
              ),
              const SizedBox(height: 9),
              _audienceOption(
                title: 'Choose Classes',
                subtitle: _chosen.isEmpty
                    ? 'Select multiple classes'
                    : _chosen.join(', '),
                icon: Icons.groups_rounded,
                selected: _audience == 2,
                onTap: _pickClasses,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // AUDIENCE SUMMARY
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: _primary, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '$_families families will receive this circular',
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // CATEGORY
          _sectionTitle(
            'Circular Type',
            'Select the category of announcement',
          ),

          const SizedBox(height: 11),

          Wrap(
            spacing: 8,
            runSpacing: 9,
            children: [
              for (final category in _categories) _categoryChip(category),
            ],
          ),

          if (_category != 'Notice') ...[
            const SizedBox(height: 14),
            _dateSelector(),
          ],

          const SizedBox(height: 22),

          // TEMPLATES
          _sectionTitle(
            'Quick Templates',
            'Tap a template to fill the title and message',
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _templates[i];
                return ActionChip(
                  avatar: Icon(t.icon, size: 15, color: _primary),
                  label: Text(t.label),
                  onPressed: () => _applyTemplate(t),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFDCE9E3)),
                  labelStyle: const TextStyle(
                    color: _dark,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // TITLE
          _sectionTitle(
            'Circular Title',
            'Give your announcement a clear heading',
          ),

          const SizedBox(height: 11),

          TextField(
            controller: _title,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDecoration(
              hint: 'e.g. Dussehra Holiday Announcement',
              icon: Icons.title_rounded,
            ),
          ),

          const SizedBox(height: 12),

          // MESSAGE
          _sectionTitle('Message', 'Write the details for parents'),

          const SizedBox(height: 11),

          TextField(
            controller: _message,
            maxLines: 5,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDecoration(
              hint: 'Write the message for parents...',
              icon: Icons.edit_note_rounded,
            ).copyWith(alignLabelWithHint: true),
          ),

          const SizedBox(height: 13),

          // ATTACHMENT
          _sectionTitle(
            'Attachment',
            'Add a PDF or image if required (optional)',
          ),

          const SizedBox(height: 11),

          if (_attachment == null)
            InkWell(
              onTap: _attach,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFDCE8E2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.attach_file_rounded, color: _primary, size: 22),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attach PDF / Image',
                            style: TextStyle(
                              color: _dark,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose an optional attachment · Demo',
                            style: TextStyle(color: _muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.add_circle_outline_rounded, color: _primary),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5ECE9)),
              ),
              child: Row(
                children: [
                  Icon(
                    _attachment!.endsWith('.pdf')
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                    color: _primary,
                    size: 21,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _attachment!,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove attachment',
                    onPressed: () => setState(() => _attachment = null),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFE16B61),
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 22),

          // DELIVERY OPTIONS
          _sectionTitle(
            'Delivery Options',
            'When and how parents receive this circular',
          ),

          const SizedBox(height: 11),

          _deliveryOptions(),

          // DRAFTS
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _sectionTitle(
                    'Saved Drafts',
                    'Tap a draft to continue editing',
                  ),
                ),
                _pill('${_drafts.length}', _primary),
              ],
            ),
            const SizedBox(height: 11),
            for (final d in _drafts) _draftCard(d),
          ],

          const SizedBox(height: 22),

          // HISTORY
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  'Sent Circulars',
                  'Your recent circular history',
                ),
              ),
              _pill('${history.length} sent', _primary),
            ],
          ),

          const SizedBox(height: 11),

          if (history.isEmpty)
            _emptyHistory()
          else
            for (final circular in history) _historyCard(circular),

          const SizedBox(height: 12),

          // PREVIEW + SEND (after Sent Circulars)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _preview,
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFB9DCD2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(
                  title: _isSending
                      ? 'Please wait...'
                      : _scheduleLater
                      ? 'Schedule for $_families Families'
                      : 'Send to $_families Families',
                  icon: _scheduleLater
                      ? Icons.schedule_send_rounded
                      : Icons.notifications_active_outlined,
                  onPressed: _isSending ? null : _send,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Center(
            child: TextButton.icon(
              onPressed: _saveDraft,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text(
                'Save as draft',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              style: TextButton.styleFrom(foregroundColor: _muted),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // WIDGETS
  // ---------------------------------------------------------------
  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _dark,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10)),
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _deliveryOptions() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EEEA)),
      ),
      child: Column(
        children: [
          // Send now / schedule
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _whenOption('Send now', Icons.bolt_rounded, false)),
                Expanded(
                  child: _whenOption('Schedule', Icons.schedule_rounded, true),
                ),
              ],
            ),
          ),
          if (_scheduleLater) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickSchedule,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5ECE9)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      color: _primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _scheduledFor == null
                            ? 'Choose date and time'
                            : _dateTimeLabel(_scheduledFor!),
                        style: TextStyle(
                          color: _scheduledFor == null ? _muted : _dark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _muted),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          _switchRow(
            icon: Icons.priority_high_rounded,
            color: _danger,
            title: 'Mark as important',
            subtitle: 'Shows an “Important” tag for parents',
            value: _important,
            onChanged: (v) => setState(() => _important = v),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1EF)),
          _switchRow(
            icon: Icons.fact_check_outlined,
            color: _primary,
            title: 'Ask for acknowledgement',
            subtitle: 'Parents confirm that they have read it',
            value: _needsAck,
            onChanged: (v) => setState(() => _needsAck = v),
          ),
        ],
      ),
    );
  }

  Widget _whenOption(String label, IconData icon, bool schedule) {
    final selected = _scheduleLater == schedule;

    return GestureDetector(
      onTap: () => setState(() => _scheduleLater = schedule),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        height: 36,
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : _muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _dark,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                  ? _primary
                  : const Color(0xFFCBD5D1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _audienceOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0F8F5) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? _primary : const Color(0xFFE6ECE9),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFDDF2EC)
                      : const Color(0xFFF1F5F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: selected ? _primary : _muted,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? _primary : _muted,
                    size: 19,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String category) {
    final selected = _category == category;
    final color = _categoryColors[category]!;

    return ChoiceChip(
      avatar: Icon(
        _categoryIcons[category],
        size: 15,
        color: selected ? color : _muted,
      ),
      label: Text(category),
      selected: selected,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.13),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.55) : const Color(0xFFE5ECE9),
      ),
      labelStyle: TextStyle(
        color: selected ? color : _dark,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) {
        setState(() {
          _category = category;
          if (category == 'Notice') _eventDate = null;
        });
      },
    );
  }

  Widget _categoryBadge(String category) {
    final color = _categoryColors[category] ?? _primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIcons[category] ?? Icons.description, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            category,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateSelector() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5ECE9)),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F3EE),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.calendar_month_rounded, color: _primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _eventDate == null
                        ? 'Select $_category Date'
                        : '$_category Date',
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _eventDate == null
                        ? 'Choose a date for the school calendar'
                        : AppState.dateLabel(_eventDate!),
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA1AAA6), fontSize: 11),
      prefixIcon: Icon(icon, color: _primary, size: 19),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5ECE9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5ECE9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
    );
  }

  Widget _draftCard(_Draft d) {
    final color = _categoryColors[d.category] ?? _primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EEEA)),
      ),
      child: InkWell(
        onTap: () => _loadDraft(d),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title.isEmpty ? '(No title)' : d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${d.category} · saved ${AppState.timeLabel(d.savedAt)}',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete draft',
                onPressed: () => _deleteDraft(d),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: Color(0xFFD47A70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyCard(CircularRecord circular) {
    final color = _categoryColors[circular.category] ?? _primary;
    final icon = _categoryIcons[circular.category] ?? Icons.description;
    final extra = _extras[circular];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE7EEEA)),
      ),
      child: InkWell(
        onTap: () => _openHistoryDetails(circular),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circular.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${circular.category} · ${circular.audience}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${circular.families} families'
                          '${circular.eventDate == null ? '' : ' · ${AppState.shortDate(circular.eventDate!)}'}',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    if (extra != null &&
                        (extra.important ||
                            extra.needsAck ||
                            extra.scheduledFor != null)) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          if (extra.important) _pill('Important', _danger),
                          if (extra.needsAck)
                            _pill('Acknowledgement', const Color(0xFF8066C8)),
                          if (extra.scheduledFor != null)
                            _pill(
                              'Scheduled · ${AppState.shortDate(extra.scheduledFor!)}',
                              const Color(0xFFE39A3A),
                            ),
                        ],
                      ),
                    ],
                    if (circular.attachment != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_file_rounded,
                            size: 12,
                            color: _primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            circular.attachment!,
                            style: const TextStyle(color: _primary, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    extra?.scheduledFor != null
                        ? Icons.schedule_rounded
                        : Icons.check_circle_rounded,
                    color: extra?.scheduledFor != null
                        ? const Color(0xFFE39A3A)
                        : _primary,
                    size: 17,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    AppState.timeLabel(circular.sentAt),
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EEEA)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 34,
            color: Color(0xFF9BAAA4),
          ),
          SizedBox(height: 9),
          Text(
            'No circulars yet',
            style: TextStyle(
              color: _dark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Your sent circulars will appear here.',
            style: TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}