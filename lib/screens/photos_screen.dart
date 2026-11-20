import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/page_app_bar.dart';

class _Photo {
  _Photo(this.colorIndex, [Set<String>? tags]) : tags = tags ?? <String>{};

  final int colorIndex;
  final Set<String> tags;
}

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  static const Color _primary = Color(0xFF2F8877);
  static const Color _dark = Color(0xFF24313D);
  static const Color _muted = Color(0xFF7B8794);
  static const Color _warn = Color(0xFFD9822B);

  static const int _maxPhotos = 10;

  static const List<Color> _tileBg = [
    Color(0xFFFFE3DC),
    Color(0xFFFFEBCF),
    Color(0xFFDCEBFF),
    Color(0xFFD9F1E8),
    Color(0xFFE6E0FA),
    Color(0xFFFFDDE0),
  ];

  static const List<Color> _tileFg = [
    Color(0xFFE8765B),
    Color(0xFFE59A2E),
    Color(0xFF4A8EE8),
    Color(0xFF2E9E7B),
    Color(0xFF7C5CE6),
    Color(0xFFE0535F),
  ];

  static const List<IconData> _photoIcons = [
    Icons.palette_rounded,
    Icons.toys_rounded,
    Icons.menu_book_rounded,
    Icons.music_note_rounded,
    Icons.sports_soccer_rounded,
    Icons.celebration_rounded,
  ];

  static const List<String> _children = [
    'Aarav',
    'Diya',
    'Kabir',
    'Saanvi',
    'Vihaan',
    'Anaya',
    'Vivaan',
    'Advik',
  ];

  static const List<String> _activities = [
    'Art & Craft',
    'Play Time',
    'Story Time',
    'Music',
    'Outdoor',
    'Celebration',
  ];

  final TextEditingController _caption = TextEditingController();

  int _mode = 0; // 0 = selected children, 1 = whole class
  int _counter = 6;
  String? _activity;
  bool _sending = false;

  final List<_Photo> _photos = [
    _Photo(0, {'Aarav'}),
    _Photo(1, {'Aarav', 'Diya'}),
    _Photo(2, {'Aarav', 'Saanvi'}),
    _Photo(3, {'Diya'}),
    _Photo(4, {'Saanvi'}),
    _Photo(5),
  ];

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------
  void _msg(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: action,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Map<String, int> get _tagCounts {
    final map = <String, int>{};

    for (final child in _children) {
      final count = _photos.where((p) => p.tags.contains(child)).length;
      if (count > 0) map[child] = count;
    }

    return map;
  }

  int get _untaggedCount => _photos.where((p) => p.tags.isEmpty).length;

  Set<String> get _allTaggedChildren =>
      _photos.fold<Set<String>>(<String>{}, (set, p) => set..addAll(p.tags));

  // ---------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------
  void _addPhotos(String source, int howMany) {
    final room = _maxPhotos - _photos.length;

    if (room <= 0) {
      _msg('You can send up to $_maxPhotos photos at a time.');
      return;
    }

    final toAdd = howMany > room ? room : howMany;

    HapticFeedback.selectionClick();

    setState(() {
      for (var i = 0; i < toAdd; i++) {
        final tagged = _children[_counter % _children.length];
        _photos.add(_Photo(_counter % _tileBg.length, {tagged}));
        _counter++;
      }
    });

    _msg(
      toAdd == 1
          ? '$source demo photo added.'
          : '$toAdd photos added from $source.',
    );
  }

  void _removePhoto(int index) {
    final removed = _photos[index];

    setState(() => _photos.removeAt(index));

    _msg(
      'Photo removed.',
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          setState(() {
            _photos.insert(index.clamp(0, _photos.length), removed);
          });
        },
      ),
    );
  }

  void _clearAll() {
    if (_photos.isEmpty) return;

    final backup = List<_Photo>.from(_photos);

    setState(_photos.clear);

    _msg(
      'All photos removed.',
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () => setState(() => _photos.addAll(backup)),
      ),
    );
  }

  Future<void> _send() async {
    if (_photos.isEmpty || _sending) return;

    if (_mode == 0 && _untaggedCount > 0) {
      _msg(
        '$_untaggedCount photo(s) have no child tagged. '
            'Please tag them before sending.',
      );
      return;
    }

    final count = _photos.length;
    final photoWord = count == 1 ? 'photo' : 'photos';
    final audience = _mode == 0
        ? 'parents of ${_allTaggedChildren.length} tagged '
        '${_allTaggedChildren.length == 1 ? 'child' : 'children'}'
        : 'all ${AppState.instance.totalChildren} children '
        'of ${AppState.instance.className}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Send photos?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '$count $photoWord will be shared with $audience.'
              '${_activity != null ? '\nActivity: $_activity' : ''}'
              '${_caption.text.trim().isNotEmpty ? '\nCaption: ${_caption.text.trim()}' : ''}',
          style: const TextStyle(fontSize: 12.5, height: 1.6),
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
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    AppState.instance.addPhotos(count);

    setState(() {
      _sending = false;
      _photos.clear();
      _caption.clear();
      _activity = null;
    });

    _msg('$count $photoWord shared with $audience.');
  }

  // ---------------------------------------------------------------
  // TAG SHEET (single photo + bulk)
  // ---------------------------------------------------------------
  void _openTagSheet({
    required String title,
    required String subtitle,
    required Set<String> initial,
    required void Function(Set<String>) onSave,
    String saveLabel = 'Save Tags',
  }) {
    final selected = Set<String>.from(initial);

    showModalBottomSheet<void>(
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCE4DF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: _dark,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheet(
                                () => selected.addAll(_children),
                          ),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () => setSheet(selected.clear),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final child in _children)
                          FilterChip(
                            label: Text(child),
                            selected: selected.contains(child),
                            selectedColor: AppColors.primaryLight,
                            checkmarkColor: _primary,
                            onSelected: (value) {
                              setSheet(() {
                                if (value) {
                                  selected.add(child);
                                } else {
                                  selected.remove(child);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppButton(
                      title: saveLabel,
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => onSave(selected));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _editTags(_Photo photo) {
    _openTagSheet(
      title: 'Who is in this photo?',
      subtitle: 'Select all children visible in this photo.',
      initial: photo.tags,
      onSave: (set) {
        photo.tags
          ..clear()
          ..addAll(set);
      },
    );
  }

  void _tagAll() {
    if (_photos.isEmpty) return;

    _openTagSheet(
      title: 'Tag all photos',
      subtitle: 'Selected children will be added to all ${_photos.length} photos.',
      initial: <String>{},
      saveLabel: 'Apply to all photos',
      onSave: (set) {
        for (final p in _photos) {
          p.tags.addAll(set);
        }
      },
    );
  }

  // ---------------------------------------------------------------
  // PREVIEW
  // ---------------------------------------------------------------
  void _preview(int index) {
    final photo = _photos[index];
    final colorIndex = photo.colorIndex % _tileBg.length;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _tileBg[colorIndex],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _photoIcons[colorIndex],
                  size: 80,
                  color: _tileFg[colorIndex],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Photo ${index + 1} of ${_photos.length}',
                style: const TextStyle(
                  color: _dark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (photo.tags.isEmpty)
                const Text(
                  'No child tagged',
                  style: TextStyle(
                    color: _warn,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in photo.tags)
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
                          t,
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editTags(photo);
                      },
                      icon: const Icon(Icons.sell_outlined, size: 16),
                      label: const Text('Edit tags'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: Color(0xFFCDE6DC)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _removePhoto(index);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Color(0xFFF5CFCF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final counts = _tagCounts;
    final count = _photos.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: buildPageAppBar(
        title: 'Photos',
        subtitle: '${AppState.instance.className} · Today',
        onBack: widget.onBack,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              children: [
                // RECEIVER TOGGLE (compact)
                _sectionLabel('SEND TO'),
                const SizedBox(height: 7),
                _receiverToggle(),

                const SizedBox(height: 14),

                // CAMERA / GALLERY (compact)
                _sectionLabel('ADD PHOTOS'),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _sourceButton(
                        title: 'Camera',
                        icon: Icons.camera_alt_rounded,
                        onTap: () => _addPhotos('Camera', 1),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _sourceButton(
                        title: 'Gallery',
                        icon: Icons.photo_library_rounded,
                        onTap: () => _addPhotos('Gallery', 3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // PHOTO GRID HEADER
                Row(
                  children: [
                    const Text(
                      'Selected Photos',
                      style: TextStyle(
                        color: _dark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count / $_maxPhotos',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_mode == 0 && count > 0)
                      _miniAction(Icons.sell_outlined, 'Tag all', _primary, _tagAll),
                    if (count > 0)
                      _miniAction(
                        Icons.delete_sweep_outlined,
                        'Clear',
                        Colors.red,
                        _clearAll,
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_photos.isEmpty)
                  _emptyPhotos()
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _photos.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 9,
                      childAspectRatio: 0.91,
                    ),
                    itemBuilder: (context, index) {
                      final photo = _photos[index];
                      final noTag = _mode == 0 && photo.tags.isEmpty;

                      return _photoTile(photo, index, noTag);
                    },
                  ),

                const SizedBox(height: 16),

                // TAGGED CHILDREN / WHOLE CLASS
                if (_mode == 0)
                  _taggedChildrenCard(counts)
                else
                  _wholeClassCard(),

                const SizedBox(height: 16),

                // ACTIVITY
                const Text(
                  'Activity',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Optional — helps parents see what the photos are about.',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final a in _activities) _activityChip(a),
                  ],
                ),

                const SizedBox(height: 16),

                // CAPTION
                const Text(
                  'Photo Caption',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: _caption,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. Rhyme time and colouring with crayons...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFA1AAA6),
                      fontSize: 11,
                    ),
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
                      borderSide: const BorderSide(color: _primary),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // SEND SECTION (appears after the caption)
                _buildSendSection(),
              ],
            ),
          ),

        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // WIDGETS
  // ---------------------------------------------------------------
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _muted,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }

  // Warning + Send button, shown at the end of the scrolling screen
  Widget _buildSendSection() {
    final count = _photos.length;

    return Column(
      children: [
        if (_mode == 0 && _untaggedCount > 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6EA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF5DDBB)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: _warn,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_untaggedCount photo(s) need child tags.',
                    style: const TextStyle(
                      color: _warn,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        AppButton(
          title: _sending
              ? 'Sending...'
              : 'Send $count ${count == 1 ? 'Photo' : 'Photos'}',
          icon: Icons.send_rounded,
          onPressed: (_photos.isEmpty || _sending) ? null : _send,
        ),
      ],
    );
  }

  // Small pill toggle: Selected Children | Whole Class
  Widget _receiverToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5ECE9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleOption(
              'Selected Children',
              Icons.person_pin_circle_outlined,
              0,
            ),
          ),
          Expanded(
            child: _toggleOption(
              'Whole Class',
              Icons.groups_2_outlined,
              1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleOption(String label, IconData icon, int value) {
    final selected = _mode == value;

    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : _muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : _dark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Small Camera / Gallery button
  Widget _sourceButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFDCE9E3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _primary, size: 18),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: _dark,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniAction(
      IconData icon,
      String label,
      Color color,
      VoidCallback onTap,
      ) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _activityChip(String label) {
    final selected = _activity == label;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: _primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? _primary : const Color(0xFFE5ECE9),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _dark,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => setState(() => _activity = selected ? null : label),
    );
  }

  Widget _photoTile(_Photo photo, int index, bool noTag) {
    final colorIndex = photo.colorIndex % _tileBg.length;

    return InkWell(
      onTap: () => _preview(index),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: _tileBg[colorIndex],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: noTag ? _warn : Colors.white,
            width: noTag ? 1.7 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                _photoIcons[colorIndex],
                color: _tileFg[colorIndex],
                size: 34,
              ),
            ),
            Positioned(
              top: 5,
              right: 5,
              child: InkWell(
                onTap: () => _removePhoto(index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 24,
                  width: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: _dark,
                  ),
                ),
              ),
            ),
            if (_mode == 0)
              Positioned(
                left: 5,
                right: 5,
                bottom: 5,
                child: InkWell(
                  onTap: () => _editTags(photo),
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      noTag ? 'Tap to tag' : photo.tags.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: noTag ? _warn : _dark,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _taggedChildrenCard(Map<String, int> counts) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tagged Children',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${counts.length} of ${_children.length}',
                style: const TextStyle(
                  color: _primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (counts.isEmpty)
            const Text(
              'No child tagged yet.',
              style: TextStyle(color: _muted, fontSize: 11),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final entry in counts.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${entry.key} · ${entry.value} '
                          '${entry.value == 1 ? 'photo' : 'photos'}',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          const Text(
            'Parents receive photos tagged with their child. '
                'Please verify the tags before sharing.',
            style: TextStyle(color: _muted, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _wholeClassCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD9E7F8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.groups_rounded,
            color: Color(0xFF3979B7),
            size: 25,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'These photos will be shared with all '
                  '${AppState.instance.totalChildren} children '
                  'of ${AppState.instance.className}.',
              style: const TextStyle(
                color: Color(0xFF326A9E),
                fontSize: 10,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPhotos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5ECE9)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            color: Color(0xFF9BAAA4),
            size: 38,
          ),
          SizedBox(height: 10),
          Text(
            'No photos selected',
            style: TextStyle(
              color: _dark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Use Camera or Gallery to add photos.',
            style: TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}