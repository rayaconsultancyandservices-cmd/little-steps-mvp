import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../widgets/page_app_bar.dart';

// Attendance status codes
const String _kPresent = 'P';
const String _kAbsent = 'A';
const String _kLate = 'L';

class _Student {
  _Student(this.name);

  final String name;
  String? status;
  String? reason; // absence reason
  int? aiConfidence;
  bool aiUnsure = false;
  bool notSeen = false;
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const Color green = Color(0xFF269B73);
  static const Color red = Color(0xFFE36B61);
  static const Color orange = Color(0xFFD99437);
  static const Color dark = Color(0xFF183B45);
  static const Color primary = Color(0xFF168C80);
  static const Color muted = Color(0xFF84918D);

  static const List<String> _reasons = [
    'Sick / Fever',
    'Family function',
    'Travelling',
    'Informed by parent',
    'Not informed',
  ];

  final TextEditingController searchController = TextEditingController();

  final List<_Student> students = <String>[
    'Aarav Mehta',
    'Diya Iyer',
    'Kabir Sharma',
    'Saanvi Rao',
    'Vihaan Joshi',
    'Anaya Patil',
    'Vivaan Deshmukh',
    'Advik Shah',
    'Ira Kulkarni',
    'Reyansh More',
    'Myra Pawar',
    'Arjun Singh',
    'Aadhya Kale',
    'Kiara Mehta',
    'Rudra Jadhav',
    'Pari Gupta',
    'Atharv Shinde',
    'Sara Khan',
    'Omkar Pawar',
    'Ishaan More',
    'Riya Patil',
    'Vedant Joshi',
  ].map(_Student.new).toList();

  int selectedFilter = 0;
  bool aiScanned = false;
  bool isScanning = false;
  bool isSaving = false;
  String searchQuery = '';

  // ---------------------------------------------------------------
  // COUNTS
  // ---------------------------------------------------------------
  int get lateCount => students.where((s) => s.status == _kLate).length;

  /// Present includes late students (they are in class).
  int get present =>
      students.where((s) => s.status == _kPresent || s.status == _kLate).length;

  int get absent => students.where((s) => s.status == _kAbsent).length;

  int get notMarked => students.where((s) => s.status == null).length;

  int get total => students.length;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------
  void markStudent(_Student student, String status) {
    HapticFeedback.selectionClick();
    setState(() {
      // Tap the same button again to un-mark.
      if (student.status == status) {
        student.status = null;
      } else {
        student.status = status;
      }
      if (student.status != _kAbsent) student.reason = null;
      student.aiUnsure = false;
      student.notSeen = false;
    });
  }

  Future<void> _pickReason(_Student student) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
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
                'Absence reason',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                student.name,
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reasons.map((r) {
                  final selected = student.reason == r;
                  return ChoiceChip(
                    label: Text(r),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: red,
                    backgroundColor: const Color(0xFFFFF1EF),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : red,
                    ),
                    onSelected: (_) => Navigator.pop(ctx, r),
                  );
                }).toList(),
              ),
              if (student.reason != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('Remove reason'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;
    setState(() => student.reason = picked.isEmpty ? null : picked);
  }

  // ---------------------------------------------------------------
  // AI CAMERA DEMO
  // ---------------------------------------------------------------
  Future<void> scanWithCamera() async {
    if (isScanning) return;

    setState(() => isScanning = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 55,
              width: 55,
              child: CircularProgressIndicator(
                color: primary,
                strokeWidth: 4,
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Scanning Classroom...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: dark,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'AI attendance demo is processing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.of(context).pop();

    const unsure = {2, 9};
    const notSeen = {4, 15};

    setState(() {
      isScanning = false;
      aiScanned = true;

      for (int i = 0; i < students.length; i++) {
        final student = students[i];

        student.aiUnsure = false;
        student.notSeen = false;
        student.reason = null;

        if (unsure.contains(i)) {
          student.status = null;
          student.aiConfidence = 62;
          student.aiUnsure = true;
        } else if (notSeen.contains(i)) {
          student.status = null;
          student.aiConfidence = null;
          student.notSeen = true;
        } else {
          student.status = _kPresent;
          student.aiConfidence = 90 + (i * 3) % 10;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Demo scan completed. $present students marked present. Please verify.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------
  Future<void> saveAttendance() async {
    if (isSaving) return;

    if (notMarked > 0) {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Incomplete Attendance',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '$notMarked students are still not marked. '
                'Would you like to mark them Absent and continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark Absent'),
            ),
          ],
        ),
      );

      if (result != true || !mounted) return;

      setState(() {
        for (final student in students) {
          if (student.status == null) {
            student.status = _kAbsent;
            student.aiUnsure = false;
            student.notSeen = false;
          }
        }
      });
    }

    setState(() => isSaving = true);

    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    // FIX 2: प्रत्येक मुलाची खरी स्थिती (P / A / L) AppState ला पाठवली जाते.
    // पूर्वी हा map पाठवला जात नव्हता, त्यामुळे Parent ला Aarav
    // नेहमी "Present" दिसायचा, तो Absent असला तरी.
    final statuses = <String, String?>{
      for (final s in students) s.name: s.status,
    };

    AppState.instance.saveAttendance(
      present: present,
      absent: absent,
      statuses: statuses,
    );

    setState(() => isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Attendance saved: $present Present'
              '${lateCount > 0 ? ' ($lateCount Late)' : ''}, $absent Absent.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------
  // FILTERING
  // ---------------------------------------------------------------
  List<_Student> get visibleStudents {
    return students.where((student) {
      final matchesSearch =
      student.name.toLowerCase().contains(searchQuery.toLowerCase());

      bool matchesFilter;

      switch (selectedFilter) {
        case 1:
          matchesFilter =
              student.status == _kPresent || student.status == _kLate;
          break;
        case 2:
          matchesFilter = student.status == _kAbsent;
          break;
        case 3:
          matchesFilter = student.status == _kLate;
          break;
        case 4:
          matchesFilter = student.status == null;
          break;
        default:
          matchesFilter = true;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  String initials(String name) {
    return name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join();
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final list = visibleStudents;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),
      appBar: buildPageAppBar(
        title: 'Attendance',
        subtitle:
        '${AppState.instance.className} · ${AppState.dateLabel(DateTime.now())}',
        onBack: widget.onBack,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                // SMALL SUMMARY CARDS
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'Present',
                        present,
                        green,
                        const Color(0xFFE5F5ED),
                        Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        'Absent',
                        absent,
                        red,
                        const Color(0xFFFFEFED),
                        Icons.cancel_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        'Pending',
                        notMarked,
                        orange,
                        const Color(0xFFFFF4E4),
                        Icons.hourglass_bottom_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // AI SCAN (compact)
                _buildScanCard(),

                const SizedBox(height: 18),

                // SEARCH
                _buildSearch(),

                const SizedBox(height: 11),

                // FILTER CHIPS
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', 0, total),
                      _filterChip('Present', 1, present),
                      _filterChip('Absent', 2, absent),
                      _filterChip('Late', 3, lateCount),
                      _filterChip('Pending', 4, notMarked),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // STUDENT LIST
                Container(
                  decoration: _cardDecoration(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        color: const Color(0xFFF8FAF9),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'STUDENTS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: muted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const _LegendDot('P', green),
                            const SizedBox(width: 9),
                            const _LegendDot('A', red),
                            const SizedBox(width: 9),
                            const _LegendDot('L', orange),
                          ],
                        ),
                      ),
                      if (list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                color: Color(0xFFADB8B4),
                                size: 35,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No students found',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: dark,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Try another name or filter.',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ],
                          ),
                        )
                      else
                        ...List.generate(list.length, (index) {
                          return Column(
                            children: [
                              _studentRow(list[index]),
                              if (index != list.length - 1)
                                const Divider(
                                  height: 1,
                                  indent: 15,
                                  endIndent: 15,
                                  color: Color(0xFFEDF1EF),
                                ),
                            ],
                          );
                        }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // SAVE SECTION (appears after the last student)
                _buildSaveSection(),
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

  // Save summary + button, shown at the end of the scrolling list
  Widget _buildSaveSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: notMarked == 0
                      ? const Color(0xFFE5F5ED)
                      : const Color(0xFFFFF4E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notMarked == 0
                      ? Icons.task_alt_rounded
                      : Icons.pending_actions_rounded,
                  color: notMarked == 0 ? green : orange,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$present / $total present',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notMarked == 0 ? 'All marked' : '$notMarked pending',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: notMarked == 0 ? green : orange,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                AppState.dateLabel(DateTime.now()),
                style: const TextStyle(
                  fontSize: 10,
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveAttendance,
              icon: isSaving
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                isSaving ? 'Saving...' : 'Save Attendance',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: muted,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Small horizontal summary card
  Widget _summaryCard(
      String title,
      int count,
      Color color,
      Color background,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '$count',
                    key: ValueKey(count),
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact AI scan strip
  Widget _buildScanCard() {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: scanWithCamera,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF104F58), Color(0xFF168C80)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.center_focus_strong_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aiScanned ? 'Scan Again' : 'AI Classroom Scan',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      aiScanned
                          ? 'Review AI results before saving'
                          : 'Auto-mark students using the camera',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: searchController,
      onChanged: (value) => setState(() => searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search student by name...',
        hintStyle: const TextStyle(color: Color(0xFFA1ADA8), fontSize: 12),
        prefixIcon: const Icon(Icons.search_rounded, color: primary),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
          onPressed: () {
            searchController.clear();
            setState(() => searchQuery = '');
          },
          icon: const Icon(Icons.close_rounded),
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
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
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _filterChip(String label, int index, int count) {
    final selected = selectedFilter == index;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => selectedFilter = index),
        backgroundColor: Colors.white,
        selectedColor: primary,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? primary : const Color(0xFFE5ECE9),
          ),
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : dark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                color: selected ? Colors.white70 : muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentRow(_Student student) {
    final isPresent = student.status == _kPresent;
    final isAbsent = student.status == _kAbsent;
    final isLate = student.status == _kLate;

    String subtitle = 'Not marked';
    Color subtitleColor = const Color(0xFF98A49F);
    Color ring = const Color(0xFFE4F3EF);
    Color avatarText = primary;

    if (isPresent) {
      subtitle = student.aiConfidence != null
          ? 'Present · AI ${student.aiConfidence}%'
          : 'Present';
      subtitleColor = green;
      ring = green;
    } else if (isLate) {
      subtitle = 'Late arrival';
      subtitleColor = orange;
      ring = orange;
    } else if (isAbsent) {
      subtitle = student.reason != null
          ? 'Absent · ${student.reason}'
          : 'Absent · Add reason';
      subtitleColor = red;
      ring = red;
    } else if (student.aiUnsure) {
      subtitle = 'AI unsure — please verify';
      subtitleColor = orange;
    } else if (student.notSeen) {
      subtitle = 'Not detected in scan';
      subtitleColor = orange;
    }

    if (student.status == null) avatarText = primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isAbsent
          ? const Color(0xFFFFFAF9)
          : isLate
          ? const Color(0xFFFFFCF6)
          : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: student.status == null
                    ? Colors.transparent
                    : ring.withValues(alpha: 0.7),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: student.status == null
                  ? const Color(0xFFE4F3EF)
                  : ring.withValues(alpha: 0.13),
              child: Text(
                initials(student.name),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: student.status == null ? avatarText : ring,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: dark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isAbsent ? () => _pickReason(student) : null,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: subtitleColor,
                      fontWeight: FontWeight.w700,
                      decoration: isAbsent && student.reason == null
                          ? TextDecoration.underline
                          : null,
                      decorationColor: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _statusButton('P', isPresent, green,
                  () => markStudent(student, _kPresent)),
          const SizedBox(width: 6),
          _statusButton(
              'A', isAbsent, red, () => markStudent(student, _kAbsent)),
          const SizedBox(width: 6),
          _statusButton(
              'L', isLate, orange, () => markStudent(student, _kLate)),
        ],
      ),
    );
  }

  Widget _statusButton(
      String label,
      bool selected,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 32,
        width: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF3F6F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5ECE9),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : muted,
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8EEEB)),
      boxShadow: [
        BoxShadow(
          color: dark.withValues(alpha: 0.025),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = switch (label) {
      'P' => 'Present',
      'A' => 'Absent',
      _ => 'Late',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 7,
          width: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF84918D),
          ),
        ),
      ],
    );
  }
}