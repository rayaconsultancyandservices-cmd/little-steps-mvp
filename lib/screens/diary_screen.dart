import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/page_app_bar.dart';

class _DiaryItem {
  _DiaryItem(
      this.label,
      String text, {
        this.custom = false,
      }) : controller = TextEditingController(text: text);

  final String label;
  final TextEditingController controller;
  final bool custom;

  void dispose() => controller.dispose();
}

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  static const Color _primary = Color(0xFF2F8877);
  static const Color _dark = Color(0xFF24313D);
  static const Color _muted = Color(0xFF7B8794);
  static const Color _warn = Color(0xFFD9822B);

  // Quick-add suggestions for "What We Learned Today"
  static const List<String> _suggestions = [
    'Story',
    'Game',
    'Shape',
    'Craft',
    'Show & Tell',
    'Free Play',
  ];

  // Class mood options
  static const List<_Mood> _moods = [
    _Mood('Happy', Icons.sentiment_very_satisfied_rounded, Color(0xFF2E9E7B)),
    _Mood('Energetic', Icons.bolt_rounded, Color(0xFFE59A2E)),
    _Mood('Calm', Icons.spa_rounded, Color(0xFF4A8EE8)),
    _Mood('Sleepy', Icons.bedtime_rounded, Color(0xFF7C5CE6)),
  ];

  // Things parents may need to send tomorrow
  final List<String> _bringOptions = [
    'Water bottle',
    'Extra clothes',
    'Crayons',
    'Red object',
    'Show & Tell item',
  ];

  final Set<String> _bring = <String>{};

  final List<_DiaryItem> _items = [
    _DiaryItem('Rhyme', 'Twinkle Twinkle Little Star'),
    _DiaryItem('Letter', 'A — Apple, Ant'),
    _DiaryItem('Number', 'Counting 1 to 5'),
    _DiaryItem('Colour', 'Red'),
    _DiaryItem('Activity', 'Colouring an apple'),
  ];

  final TextEditingController _homeNote = TextEditingController(
    text: 'Please practise the rhyme at home. '
        'Send a red-coloured object tomorrow.',
  );

  String? _mood;
  bool _notifyParents = true;
  bool _isPreviewOpen = false;
  bool _isPublishing = false;
  DateTime? _publishedAt;

  int get _filledCount =>
      _items.where((item) => item.controller.text.trim().isNotEmpty).length;

  bool get _published => AppState.instance.diaryPublished;

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _homeNote.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------
  void _showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: action,
        ),
      );
  }

  Future<String?> _askLabel({
    required String title,
    required String hint,
    required String button,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _AddItemDialog(title: title, hint: hint, button: button),
    );
  }

  Future<void> _addItem() async {
    final label = await _askLabel(
      title: 'Add Diary Item',
      hint: 'e.g. Story, Game, Shape',
      button: 'Add Item',
    );

    if (!mounted || label == null || label.trim().isEmpty) return;

    setState(() => _items.add(_DiaryItem(label.trim(), '', custom: true)));
  }

  void _quickAdd(String label) {
    setState(() => _items.add(_DiaryItem(label, '', custom: true)));
  }

  Future<void> _addBringItem() async {
    final label = await _askLabel(
      title: 'Add Item to Bring',
      hint: 'e.g. Raincoat',
      button: 'Add',
    );

    if (!mounted || label == null || label.trim().isEmpty) return;

    final value = label.trim();

    setState(() {
      if (!_bringOptions.contains(value)) _bringOptions.add(value);
      _bring.add(value);
    });
  }

  void _removeItem(int index) {
    final item = _items.removeAt(index);

    setState(() {});

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('${item.label} removed.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() => _items.insert(index.clamp(0, _items.length), item));
          },
        ),
      ),
    );

    controller.closed.then((reason) {
      // Free the controller only if the removal was not undone.
      if (reason != SnackBarClosedReason.action) item.dispose();
    });
  }

  void _reuseYesterday() {
    setState(() {
      _setText('Rhyme', 'Johny Johny Yes Papa');
      _setText('Letter', 'Z — Zebra, Zip');
      _setText('Number', 'Counting 1 to 3');
      _setText('Colour', 'Yellow');
      _setText('Activity', 'Paper boat folding');
    });

    _showMessage('Yesterday’s diary loaded. Edit as needed.');
  }

  void _setText(String label, String text) {
    for (final item in _items) {
      if (item.label == label) item.controller.text = text;
    }
  }

  Future<void> _publish() async {
    if (_isPublishing) return;

    if (_filledCount == 0) {
      _showMessage('Please write at least one diary item.');
      return;
    }

    final emptyCount = _items.length - _filledCount;
    final families = AppState.instance.totalFamilies;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _published ? 'Update diary?' : 'Publish diary?',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_filledCount of ${_items.length} items will be shared with '
                  '$families families of ${AppState.instance.className}.',
              style: const TextStyle(fontSize: 12.5, height: 1.5),
            ),
            if (emptyCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$emptyCount empty item(s) will be skipped.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _warn,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _notifyParents
                  ? 'Parents will get a notification.'
                  : 'Parents will not be notified.',
              style: const TextStyle(fontSize: 11.5, color: _muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(_published ? 'Update' : 'Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final wasPublished = _published;

    setState(() => _isPublishing = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    AppState.instance.publishDiary();

    setState(() {
      _isPublishing = false;
      _publishedAt = DateTime.now();
    });

    _showMessage(
      wasPublished
          ? 'Diary updated successfully.'
          : 'Diary published successfully.',
    );
  }

  Future<void> _showPreview() async {
    if (_filledCount == 0) {
      _showMessage('Add at least one activity to preview.');
      return;
    }

    setState(() => _isPreviewOpen = true);

    final moodData = _mood == null
        ? null
        : _moods.firstWhere((m) => m.label == _mood);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
                          'Diary Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    AppState.instance.className,
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    AppState.dateLabel(DateTime.now()),
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  if (moodData != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: moodData.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(moodData.icon, size: 15, color: moodData.color),
                          const SizedBox(width: 5),
                          Text(
                            'Class mood: ${moodData.label}',
                            style: TextStyle(
                              color: moodData.color,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 25),
                  const Text(
                    'TODAY WE LEARNED',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in _items)
                    if (item.controller.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 17,
                              color: _primary,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.controller.text.trim(),
                                    style: const TextStyle(
                                      color: _dark,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  if (_homeNote.text.trim().isNotEmpty) ...[
                    const Divider(height: 22),
                    const Text(
                      'NOTE TO PARENTS',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _homeNote.text.trim(),
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                  if (_bring.isNotEmpty) ...[
                    const Divider(height: 22),
                    const Text(
                      'PLEASE SEND TOMORROW',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final b in _bring)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              b,
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

    if (mounted) setState(() => _isPreviewOpen = false);
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final published = _published;

    // Suggestions that are not already added
    final existing = _items.map((e) => e.label.toLowerCase()).toSet();
    final availableSuggestions =
    _suggestions.where((s) => !existing.contains(s.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: buildPageAppBar(
        title: 'Class Diary',
        subtitle:
        '${AppState.instance.className} · ${AppState.dateLabel(DateTime.now())}',
        onBack: widget.onBack,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // TAUGHT TODAY
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _sectionHeading(
                  'What We Learned Today',
                  'Add the topics and activities taught in class',
                  icon: Icons.auto_stories_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _reuseYesterday,
              icon: const Icon(Icons.history_rounded, size: 15),
              label: const Text(
                'Reuse yesterday’s diary',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _items.length; i++) _itemRow(i, _items[i]),

                if (availableSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'QUICK ADD',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in availableSuggestions)
                        ActionChip(
                          avatar: const Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: _primary,
                          ),
                          label: Text(s),
                          onPressed: () => _quickAdd(s),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFFF1F8F5),
                          side: BorderSide.none,
                          labelStyle: const TextStyle(
                            color: _primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 11),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: const Text('Add custom activity'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: Color(0xFFB9DCD2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // CLASS MOOD
          _sectionHeading(
            'Class Mood',
            'How was the class today?',
            icon: Icons.emoji_emotions_outlined,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              for (var i = 0; i < _moods.length; i++) ...[
                Expanded(child: _moodChip(_moods[i])),
                if (i != _moods.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),

          const SizedBox(height: 22),

          // PRACTICE AT HOME
          _sectionHeading(
            'Practice at Home',
            'A message or reminder for parents',
            icon: Icons.home_work_outlined,
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                      color: _primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Note to Parents',
                      style: TextStyle(
                        color: _dark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _homeNote,
                  maxLines: 4,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Write a note for parents...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFA1AAA6),
                      fontSize: 11,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F9F8),
                    alignLabelWithHint: true,
                    contentPadding: const EdgeInsets.all(13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.backpack_outlined, size: 17, color: _primary),
                    SizedBox(width: 8),
                    Text(
                      'Please send tomorrow',
                      style: TextStyle(
                        color: _dark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final option in _bringOptions) _bringChip(option),
                    ActionChip(
                      avatar: const Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: _primary,
                      ),
                      label: const Text('Other'),
                      onPressed: _addBringItem,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFB9DCD2)),
                      labelStyle: const TextStyle(
                        color: _primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // NOTIFY PARENTS
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: _primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notify parents',
                        style: TextStyle(
                          color: _dark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Send a push notification when published',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _notifyParents,
                  thumbColor: const WidgetStatePropertyAll(Colors.white),
                  trackColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                        ? _primary
                        : const Color(0xFFCBD5D1),
                  ),
                  onChanged: (v) => setState(() => _notifyParents = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // PUBLISH STATUS
          if (published)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBE7D9)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF278B65),
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _publishedAt != null
                          ? 'Published at ${AppState.timeLabel(_publishedAt!)}. '
                          'You can make changes and update it.'
                          : 'Today’s diary is marked as published. '
                          'You can make changes and update it.',
                      style: const TextStyle(
                        color: Color(0xFF267653),
                        fontSize: 11,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // PREVIEW + PUBLISH (after Practice at Home)
          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isPreviewOpen ? null : _showPreview,
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
                  title: _isPublishing
                      ? 'Please wait...'
                      : published
                      ? 'Update Diary'
                      : 'Publish Diary',
                  icon: published ? Icons.refresh_rounded : Icons.send_rounded,
                  onPressed: _isPublishing ? null : _publish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // WIDGETS
  // ---------------------------------------------------------------
  Widget _sectionHeading(
      String title,
      String subtitle, {
        required IconData icon,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 37,
          width: 37,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2ED),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: _primary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
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
              Text(
                subtitle,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moodChip(_Mood mood) {
    final selected = _mood == mood.label;

    return GestureDetector(
      onTap: () => setState(() => _mood = selected ? null : mood.label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? mood.color.withValues(alpha: 0.13) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? mood.color : const Color(0xFFE5ECE9),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              mood.icon,
              size: 23,
              color: selected ? mood.color : const Color(0xFF9BAAA4),
            ),
            const SizedBox(height: 5),
            Text(
              mood.label,
              style: TextStyle(
                color: selected ? mood.color : _dark,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bringChip(String label) {
    final selected = _bring.contains(label);

    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: _primary,
      backgroundColor: const Color(0xFFF7F9F8),
      side: BorderSide(color: selected ? _primary : const Color(0xFFE5ECE9)),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _dark,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (value) {
        setState(() {
          if (value) {
            _bring.add(label);
          } else {
            _bring.remove(label);
          }
        });
      },
    );
  }

  Widget _itemRow(int index, _DiaryItem item) {
    final hasText = item.controller.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(11, 7, 5, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFEDF1EF)),
      ),
      child: Row(
        children: [
          Container(
            height: 35,
            width: 35,
            decoration: BoxDecoration(
              color:
              hasText ? const Color(0xFFE3F2ED) : const Color(0xFFFFF0D9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconFor(item.label),
              size: 18,
              color: hasText ? _primary : const Color(0xFFD99A39),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: _dark,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (hasText)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: _primary,
                        size: 14,
                      ),
                  ],
                ),
                TextField(
                  controller: item.controller,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Tap to write...',
                    hintStyle: TextStyle(
                      color: Color(0xFFA1AAA6),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.only(top: 5, bottom: 4),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove item',
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeItem(index),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Color(0xFFD47A70),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String label) {
    switch (label.toLowerCase()) {
      case 'rhyme':
        return Icons.music_note_rounded;
      case 'letter':
        return Icons.abc_rounded;
      case 'number':
        return Icons.calculate_outlined;
      case 'colour':
      case 'color':
        return Icons.palette_outlined;
      case 'activity':
        return Icons.brush_rounded;
      case 'story':
        return Icons.menu_book_rounded;
      case 'game':
        return Icons.sports_esports_outlined;
      case 'shape':
        return Icons.category_outlined;
      case 'craft':
        return Icons.content_cut_rounded;
      case 'show & tell':
        return Icons.record_voice_over_outlined;
      case 'free play':
        return Icons.toys_outlined;
      default:
        return Icons.edit_note_rounded;
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE8EEEB)),
      boxShadow: [
        BoxShadow(
          color: _dark.withValues(alpha: 0.025),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _Mood {
  const _Mood(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog({
    required this.title,
    required this.hint,
    required this.button,
  });

  final String title;
  final String hint;
  final String button;

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final TextEditingController _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      content: TextField(
        controller: _label,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 30,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.edit_note_rounded),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.pop(context, value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_label.text.trim().isNotEmpty) {
              Navigator.pop(context, _label.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F8877),
            foregroundColor: Colors.white,
          ),
          child: Text(widget.button),
        ),
      ],
    );
  }
}