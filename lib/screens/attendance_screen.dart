import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/face_match_service.dart';
import '../state/app_state.dart';
import '../widgets/page_app_bar.dart';

// Attendance status codes
const String _kPresent = 'P';
const String _kAbsent = 'A';
const String _kLate = 'L';

// नवीन: मंजूर रजा असतानाही मूल शाळेत आलं, तर Teacher ने Present केल्यावर हा शेरा
// (reason) save होतो. त्यावरून पुढच्या वेळी कळतं की हा Present जाणूनबुजून केलेला आहे,
// आणि तो पुन्हा आपोआप Absent केला जात नाही. Parent ला पण हा शेरा दिसतो.
const String _kCameOnLeave = 'Came despite approved leave';

class _Student {
  _Student(this.id, this.name);

  final String id; // Firestore student id
  final String name;
  bool touched = false; // Teacher ने या session मध्ये स्वतः mark केलं का
  // नवीन: मंजूर रजेमुळे आपोआप Absent झालं आहे का (Teacher ने स्वतः mark केलेलं नाही).
  bool leaveAuto = false;
  String? status;
  String? reason; // absence reason

  // नवीन (AI scan): 0 = AI ने काही केलं नाही, 1 = AI ने Present केलं (confident),
  // 2 = AI ला खात्री नाही, 3 = AI ला मूल दिसलं नाही.
  int aiState = 0;
  double? aiConfidence; // 0.0 - 1.0
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

  // Firestore मधील खरी students list (AppState.students) इथे mark सह ठेवली जाते.
  final List<_Student> students = [];

  int selectedFilter = 0;
  bool isSaving = false;
  String searchQuery = '';

  // ---------------------------------------------------------------
  // नवीन: मागच्या दिवसांचा attendance पाहणे (फक्त पाहता येतो, बदलता येत नाही)
  // ---------------------------------------------------------------
  DateTime _selectedDay = _dateOnly(DateTime.now());
  final List<_Student> _pastStudents = [];
  Map<String, String> _pastStatus = {};
  Map<String, String> _pastReason = {};
  bool _loadingPast = false;
  String? _pastError;
  bool _pastLoaded = false;
  int _loadToken = 0;

  // ---------------------------------------------------------------
  // नवीन: "Scan class with camera" (AI)
  // ---------------------------------------------------------------
  bool _scanning = false;
  static const double _aiSure = 0.90; // यापेक्षा जास्त = आपोआप Present
  static const double _aiMaybe = 0.60; // यादरम्यान = "AI unsure — tap P or A"

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// निवडलेला दिवस आजचा आहे का? (आजचा असेल तर नेहमीसारखं mark / save चालतं)
  bool get _isToday => _selectedDay == _dateOnly(DateTime.now());

  /// आज असेल तर आजची list, नाहीतर निवडलेल्या मागच्या दिवसाची list.
  List<_Student> get _view => _isToday ? students : _pastStudents;

  // ---------------------------------------------------------------
  // COUNTS
  // ---------------------------------------------------------------
  int get lateCount => _view.where((s) => s.status == _kLate).length;

  /// Present includes late students (they are in class).
  int get present =>
      _view.where((s) => s.status == _kPresent || s.status == _kLate).length;

  int get absent => _view.where((s) => s.status == _kAbsent).length;

  /// नवीन: आधी 'Present / Late' save झालं होतं, पण नंतर रजा मंजूर झाली, म्हणून आता
  /// आपोआप Absent केलेली मुलं. Save दाबेपर्यंत Parent app ला जुनं (Present) दिसतं.
  List<_Student> get _leaveFixed {
    final saved = AppState.instance.attendanceStatuses;
    return students.where((s) {
      final old = saved[s.id];
      return s.leaveAuto && (old == _kPresent || old == _kLate);
    }).toList();
  }

  Widget _buildLeaveFixNotice() {
    final fixed = _leaveFixed;
    if (fixed.isEmpty) return const SizedBox.shrink();
    final names = fixed.map((s) => s.name).join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9CEF3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Color(0xFF8066C8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$names ${fixed.length == 1 ? 'has' : 'have'} an approved leave '
                  'today, but was saved as Present earlier. Changed to Absent '
                  '(Approved leave). Tap Save so the parent app shows the same. '
                  'If the child really came, tap P.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B4A97),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int get notMarked => _view.where((s) => s.status == null).length;

  int get total => _view.length;

  @override
  void initState() {
    super.initState();
    _rebuildStudents();
    AppState.instance.addListener(_sync);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_sync);
    searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // REAL STUDENTS (Firestore)
  // ---------------------------------------------------------------
  /// AppState.students मधून list बनवतो. Teacher ने आधी केलेले marks तसेच राहतात;
  /// आज आधीच save केलेला attendance असेल तर तो दिसतो.
  void _rebuildStudents() {
    final app = AppState.instance;
    final old = {for (final x in students) x.id: x};
    final next = <_Student>[];

    for (final c in app.students) {
      final st = old[c.id] ?? _Student(c.id, c.name);
      // Teacher ने या session मध्ये स्वतः काही ठरवलेलं नसेल तरच आपोआप स्थिती ठरवतो.
      // बदल: आधी फक्त (status == null || leaveAuto) असेल तेव्हाच ठरवत होतो, त्यामुळे
      // आधी save झालेला 'Present' नंतर मंजूर झालेल्या रजेवर कधीच जिंकत नव्हता.
      if (!st.touched) {
        final saved = app.attendanceStatuses[c.id];
        final savedReason = app.attendanceReasons[c.id];
        final hasSaved = saved != null && saved.isNotEmpty;
        final leave = _approvedLeaveOn(c.id, _dateOnly(DateTime.now()));

        // आधी save केलेला Present / Late, पण आज रजा मंजूर आहे आणि Teacher ने
        // "रजा असूनही आला" असं स्वतः ठरवलेलं नाही -> हा mismatch आहे.
        final presentButOnLeave = hasSaved &&
            (saved == _kPresent || saved == _kLate) &&
            leave != null &&
            savedReason != _kCameOnLeave;

        if (presentButOnLeave || (!hasSaved && leave != null)) {
          // 1) मंजूर रजा -> Absent (कारण: Approved leave).
          st.status = _kAbsent;
          st.reason = 'Approved leave';
          st.leaveAuto = true;
        } else if (hasSaved) {
          // 2) आज आधीच save केलेला attendance (रजेशी विसंगत नसेल तर).
          st.status = saved;
          st.reason = savedReason;
          st.leaveAuto = false;
        } else if (st.leaveAuto) {
          // 3) रजा नंतर रद्द / नाकारली गेली -> आपोआप केलेली खूण काढतो.
          st.status = null;
          st.reason = null;
          st.leaveAuto = false;
        }
      }
      next.add(st);
    }

    students
      ..clear()
      ..addAll(next);
  }

  void _sync() {
    if (!mounted) return;
    setState(() {
      _rebuildStudents();
      if (!_isToday) _rebuildPast();
    });
  }

  // ---------------------------------------------------------------
  // AI SCAN (नवीन)
  // ---------------------------------------------------------------

  /// >>> AI FACE MATCH — हा एकच जोडण्याचा बिंदू (hook) <<<
  ///
  /// वर्गाचा फोटो (JPEG bytes) आणि मुलांची list दिली की, प्रत्येक मुलासाठी
  /// ओळखीची खात्री (0.0 – 1.0) असलेला Map परत द्यायचा: { studentId: confidence }.
  /// ज्या मुलाचा फोटोत चेहरा सापडला नाही ते Map मध्ये नसावं.
  ///
  /// `null` परत केलं तर याचा अर्थ "AI engine जोडलेलं नाही" — कोणालाही mark होत नाही.
  /// सध्या project मध्ये face-recognition package आणि मुलांचे reference face
  /// photos नाहीत, म्हणून हे `null` देतं.
  Future<Map<String, double>?> _matchFaces(
      Uint8List classPhoto, List<_Student> kids) async {
    // Admin ने ठेवलेले reference face photos (AppState.students मधून) गोळा करतो.
    final ids = kids.map((k) => k.id).toSet();
    final refs = <String, String>{
      for (final c in AppState.instance.students)
        if (ids.contains(c.id) && c.facePhoto.isNotEmpty) c.id: c.facePhoto,
    };
    return FaceMatchService.instance.match(classPhoto, refs);
  }

  Future<void> _scanClass() async {
    if (_scanning) return;

    if (students.isEmpty) {
      _snack('Add students first (tap the + icon at the top).');
      return;
    }

    XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Could not open camera: $e');
      return;
    }
    if (shot == null || !mounted) return;

    setState(() => _scanning = true);

    try {
      final bytes = await shot.readAsBytes();
      final result = await _matchFaces(bytes, List<_Student>.of(students));
      if (!mounted) return;

      if (result == null) {
        setState(() => _scanning = false);
        _snack('AI face matching is not connected yet, so nobody was marked. '
            'Please mark attendance manually.');
        return;
      }

      var sure = 0;
      var unsure = 0;
      var unseen = 0;

      setState(() {
        for (final st in students) {
          // Teacher ने आधीच mark केलेलं बदलत नाही.
          if (st.status != null) continue;

          final c = result[st.id];
          if (c != null && c >= _aiSure) {
            st.status = _kPresent;
            st.touched = true;
            st.aiState = 1;
            st.aiConfidence = c;
            sure++;
          } else if (c != null && c >= _aiMaybe) {
            st.aiState = 2;
            st.aiConfidence = c;
            unsure++;
          } else {
            st.aiState = 3;
            st.aiConfidence = null;
            unseen++;
          }
        }
        _scanning = false;
        selectedFilter = 0;
      });

      _snack('AI marked $sure present'
          '${unsure > 0 ? ', $unsure unsure' : ''}'
          '${unseen > 0 ? ', $unseen not seen' : ''}. '
          'Check and tap Save.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      _snack('Scan failed: $e');
    }
  }

  // ---------------------------------------------------------------
  // PAST ATTENDANCE (नवीन)
  // ---------------------------------------------------------------
  void _rebuildPast() {
    _pastStudents.clear();
    for (final c in AppState.instance.students) {
      final st = _Student(c.id, c.name)
        ..status = _pastStatus[c.id]
        ..reason = _pastReason[c.id];
      // नवीन: त्या दिवसाचा save केलेला record नसेल, पण त्या दिवशी रजा मंजूर
      // होती, तर Absent (Approved leave) दाखवतो. (फक्त पाहण्यासाठी)
      if ((st.status == null || st.status!.isEmpty) &&
          _pastLoaded &&
          _approvedLeaveOn(c.id, _selectedDay) != null) {
        st.status = _kAbsent;
        st.reason = 'Approved leave';
        st.leaveAuto = true;
      }
      _pastStudents.add(st);
    }
  }

  /// नवीन: या मुलाची दिलेल्या दिवसाची मंजूर (approved) रजा, नसेल तर null.
  /// (AppState.approvedLeaveToday फक्त आजसाठी आहे, म्हणून कोणत्याही दिवसासाठी
  /// इथे स्वतंत्र तपासणी केली आहे.)
  LeaveRequest? _approvedLeaveOn(String studentId, DateTime day) {
    final d = _dateOnly(day);
    for (final l in AppState.instance.leaves) {
      if (l.studentId != studentId || !l.isApproved) continue;
      final from = _dateOnly(l.fromDate);
      final to = _dateOnly(l.toDate);
      if (!d.isBefore(from) && !d.isAfter(to)) return l;
    }
    return null;
  }

  void _goToDay(DateTime day) {
    final d = _dateOnly(day);
    if (d.isAfter(_dateOnly(DateTime.now()))) return; // भविष्यातला दिवस नाही
    if (d == _selectedDay) return;

    setState(() {
      _selectedDay = d;
      selectedFilter = 0;
    });

    if (_isToday) {
      // आज: नेहमीची live list (AppState मधून), काही load करावं लागत नाही.
      _loadToken++; // चालू असलेला जुना load रद्द
      setState(() {
        _loadingPast = false;
        _pastError = null;
        _pastLoaded = false;
      });
    } else {
      _loadPast();
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: _dateOnly(now),
      helpText: 'Select attendance date',
    );
    if (picked != null) _goToDay(picked);
  }

  Future<void> _loadPast() async {
    final token = ++_loadToken;
    setState(() {
      _loadingPast = true;
      _pastError = null;
      _pastLoaded = false;
    });

    try {
      // classId + day (दोन्ही equality) — वेगळा index लागत नाही;
      // Rules: Teacher फक्त आपल्या class चा attendance वाचू शकतो.
      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('classId', isEqualTo: AppState.instance.classId)
          .where('day', isEqualTo: AppState.dayKey(_selectedDay))
          .get();

      if (!mounted || token != _loadToken) return;

      final st = <String, String>{};
      final rs = <String, String>{};
      for (final d in snap.docs) {
        final m = d.data();
        final sid = (m['studentId'] ?? '') as String;
        final status = (m['status'] ?? '') as String;
        if (sid.isEmpty || status.isEmpty) continue;
        st[sid] = status;
        final reason = (m['reason'] ?? '') as String;
        if (reason.isNotEmpty) rs[sid] = reason;
      }

      setState(() {
        _pastStatus = st;
        _pastReason = rs;
        _loadingPast = false;
        _pastLoaded = true;
        _rebuildPast();
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _pastStatus = {};
        _pastReason = {};
        _loadingPast = false;
        _pastLoaded = false;
        _pastError = '$e';
        _rebuildPast();
      });
    }
  }

  String _dayLabel(DateTime d) {
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final base = AppState.dateLabel(d);
    if (d == today) return 'Today · $base';
    if (d == yesterday) return 'Yesterday · $base';
    return '$base ${d.year}';
  }

  // ---------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------
  void markStudent(_Student student, String status) {
    HapticFeedback.selectionClick();
    setState(() {
      student.touched = true;
      student.leaveAuto = false; // आता Teacher ने स्वतः ठरवलं
      student.aiState = 0; // Teacher ने स्वतः ठरवलं — AI ची खूण काढतो
      student.aiConfidence = null;
      // Tap the same button again to un-mark.
      if (student.status == status) {
        student.status = null;
      } else {
        student.status = status;
      }
      final onLeave = AppState.instance.approvedLeaveToday(student.id) != null;
      if (student.status != _kAbsent) student.reason = null;
      // नवीन: मंजूर रजा असेल तर Absent चं कारण आपोआप भरतो.
      if (student.status == _kAbsent && student.reason == null && onLeave) {
        student.reason = 'Approved leave';
      }
      // नवीन: मंजूर रजा असूनही Teacher ने Present / Late केलं -> तसा शेरा ठेवतो,
      // म्हणजे हा निर्णय जाणूनबुजून आहे हे कळतं (आणि पुन्हा आपोआप Absent होत नाही).
      if ((student.status == _kPresent || student.status == _kLate) && onLeave) {
        student.reason = _kCameOnLeave;
      }
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
    setState(() {
      student.touched = true;
      student.leaveAuto = false;
      student.reason = picked.isEmpty ? null : picked;
    });
  }

  // ---------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------
  Future<void> saveAttendance() async {
    if (isSaving) return;

    if (students.isEmpty) {
      _snack('Add students first (tap the + icon at the top).');
      return;
    }

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
            student.touched = true;
            student.status = _kAbsent;
          }
        }
      });
    }

    setState(() => isSaving = true);

    // प्रत्येक मुलाची खरी स्थिती (P / A / L) आणि absence reason Firestore मध्ये
    // save होते; Parent app ला फक्त त्याच्या मुलाची स्थिती दिसते.
    final statuses = <String, String?>{
      for (final s in students) s.id: s.status,
    };
    final reasons = <String, String>{
      for (final s in students)
        if (s.reason != null) s.id: s.reason!,
    };

    try {
      await AppState.instance.saveAttendance(
        present: present,
        absent: absent,
        statuses: statuses,
        reasons: reasons,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _snack('Could not save attendance: $e');
      return;
    }

    if (!mounted) return;
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
    return _view.where((student) {
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
        '${AppState.instance.className} · ${AppState.dateLabel(_selectedDay)}',
        onBack: widget.onBack,
        actions: [
          IconButton(
            tooltip: 'Add student',
            onPressed: _openAddStudent,
            icon: const Icon(Icons.person_add_alt_1_rounded, color: primary),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                // नवीन: तारीख निवडा (Today / Yesterday / कोणतीही तारीख)
                _buildDayBar(),
                ..._buildPastNotices(),
                const SizedBox(height: 12),

                // नवीन: रजा मंजूर आणि Present असा mismatch असेल तर सूचना.
                if (_isToday) _buildLeaveFixNotice(),

                // नवीन: Scan class with camera (फक्त आजच्या दिवशी)
                if (_isToday) ...[
                  _buildScanCard(),
                  const SizedBox(height: 12),
                ],

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
                        _isToday ? 'Pending' : 'Not marked',
                        notMarked,
                        orange,
                        const Color(0xFFFFF4E4),
                        Icons.hourglass_bottom_rounded,
                      ),
                    ),
                  ],
                ),

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
                      _filterChip(_isToday ? 'Pending' : 'Not marked', 4, notMarked),
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
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              Icon(
                                total == 0
                                    ? Icons.group_add_rounded
                                    : Icons.search_off_rounded,
                                color: const Color(0xFFADB8B4),
                                size: 35,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                total == 0
                                    ? 'No students yet'
                                    : 'No students found',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: dark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                total == 0
                                    ? 'Tap the + icon at the top to add your first student.'
                                    : 'Try another name or filter.',
                                textAlign: TextAlign.center,
                                style:
                                const TextStyle(fontSize: 11, color: muted),
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
                // मागचा दिवस पाहताना Save नाही, फक्त summary.
                if (_isToday) _buildSaveSection() else _buildPastSummary(),
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

  // ---------------------------------------------------------------
  // नवीन WIDGETS: तारीख bar, मागच्या दिवसाचे notices, badge, summary
  // ---------------------------------------------------------------
  Widget _buildDayBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous day',
                onPressed: () =>
                    _goToDay(_selectedDay.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left_rounded, color: primary),
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickDay,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 17, color: primary),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            _dayLabel(_selectedDay),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: dark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next day',
                onPressed: _isToday
                    ? null
                    : () => _goToDay(_selectedDay.add(const Duration(days: 1))),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: _isToday ? const Color(0xFFC9D3CF) : primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPastNotices() {
    if (_isToday) return const [];

    final widgets = <Widget>[const SizedBox(height: 10)];

    widgets.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF4786C7)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Viewing past attendance (view only). '
                    'Tap Absent to see who was absent.',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4786C7),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (_loadingPast) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const LinearProgressIndicator(minHeight: 3, color: primary),
        ),
      );
    } else if (_pastError != null) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEFED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Could not load attendance: $_pastError',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: red,
                  ),
                ),
              ),
              TextButton(onPressed: _loadPast, child: const Text('Retry')),
            ],
          ),
        ),
      );
    } else if (_pastLoaded && _pastStatus.isEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No attendance was saved for this day.',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: orange,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  // मागच्या दिवसाची स्थिती दाखवणारा लहान badge (बटणांऐवजी, tap होत नाही)
  Widget _pastBadge(_Student s) {
    String text;
    Color color;
    if (s.status == _kPresent) {
      text = 'Present';
      color = green;
    } else if (s.status == _kAbsent) {
      text = 'Absent';
      color = red;
    } else if (s.status == _kLate) {
      text = 'Late';
      color = orange;
    } else {
      text = '—';
      color = muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // मागचा दिवस पाहताना Save button ऐवजी फक्त summary
  Widget _buildPastSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.history_rounded,
                color: Color(0xFF4786C7), size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$present / $total present · $absent absent',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppState.dateLabel(_selectedDay),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard() {
    const accent = Color(0xFF7C5CFC);

    return Material(
      color: const Color(0xFFEFEBFF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _scanning ? null : _scanClass,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD9D0F7)),
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: const BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: _scanning
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.crop_free_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scanning
                          ? 'Scanning class photo...'
                          : 'Scan class with camera',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'AI marks present children. You check and save.',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A6FA8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

    String subtitle = _isToday ? 'Not marked' : 'No record';
    Color subtitleColor = const Color(0xFF98A49F);
    Color ring = const Color(0xFFE4F3EF);
    Color avatarText = primary;

    if (isPresent) {
      subtitle = 'Present';
      subtitleColor = green;
      ring = green;
      // नवीन: मंजूर रजा असूनही Present केलेलं — वेगळं दिसावं.
      if (student.reason == _kCameOnLeave) {
        subtitle = 'Present · Came despite leave';
        subtitleColor = const Color(0xFF8066C8);
      }
    } else if (isLate) {
      subtitle = 'Late arrival';
      subtitleColor = orange;
      ring = orange;
    } else if (isAbsent) {
      subtitle = student.reason != null
          ? 'Absent · ${student.reason}'
          : (_isToday ? 'Absent · Add reason' : 'Absent');
      subtitleColor = red;
      ring = red;
      // नवीन: मंजूर रजेमुळे आपोआप Absent — वेगळ्या रंगात, म्हणजे ओळखू येतं.
      if (student.leaveAuto) {
        subtitle = 'Absent · On approved leave';
        subtitleColor = const Color(0xFF8066C8);
      }
    } else if (_isToday &&
        AppState.instance.approvedLeaveToday(student.id) != null) {
      // नवीन: Parent ची रजा मंजूर आहे — Teacher ला आधीच कळतं.
      subtitle = 'On approved leave today';
      subtitleColor = const Color(0xFF8066C8);
    }

    // नवीन: AI scan नंतरच्या खुणा (फक्त आजच्या दिवशी)
    if (_isToday) {
      if (isPresent && student.aiState == 1 && student.aiConfidence != null) {
        subtitle = 'AI ${(student.aiConfidence! * 100).round()}%';
      } else if (student.status == null && student.aiState == 2) {
        subtitle = 'AI unsure — tap P or A';
        subtitleColor = orange;
      } else if (student.status == null && student.aiState == 3) {
        subtitle = 'Not seen';
      }
    }

    if (student.status == null) avatarText = primary;

    return GestureDetector(
      onLongPress: () => _openStudentActions(student),
      child: AnimatedContainer(
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
                    onTap: (_isToday && isAbsent) ? () => _pickReason(student) : null,
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: subtitleColor,
                        fontWeight: FontWeight.w700,
                        decoration: _isToday && isAbsent && student.reason == null
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
            if (_isToday) ...[
              _statusButton('P', isPresent, green,
                      () => markStudent(student, _kPresent)),
              const SizedBox(width: 6),
              _statusButton(
                  'A', isAbsent, red, () => markStudent(student, _kAbsent)),
              const SizedBox(width: 6),
              _statusButton(
                  'L', isLate, orange, () => markStudent(student, _kLate)),
            ] else
              _pastBadge(student),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // ADD / REMOVE STUDENT  (नवीन: Teacher स्वतः मुलं जोडतो)
  // ---------------------------------------------------------------
  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _openAddStudent() async {
    final child = await showModalBottomSheet<ChildInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddStudentSheet(nextRoll: students.length + 1),
    );
    if (child == null || !mounted) return;

    try {
      await AppState.instance.addStudent(child);
      if (!mounted) return;
      _snack(
        '${child.name} added. Parent can login with ${child.parentEmail.trim().toLowerCase()}',
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Could not add student: $e');
    }
  }

  // ---------------------------------------------------------------
  // EDIT / REMOVE  (बदल: long-press वर आता Edit आणि Remove दोन्ही पर्याय)
  // ---------------------------------------------------------------
  Future<void> _openStudentActions(_Student student) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE5E2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: dark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: primary),
                title: const Text(
                  'Edit student details',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: red),
                title: const Text(
                  'Remove student',
                  style: TextStyle(fontWeight: FontWeight.w700, color: red),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _openEditStudent(student);
    } else if (action == 'remove') {
      await _confirmRemove(student);
    }
  }

  Future<void> _openEditStudent(_Student student) async {
    final found = AppState.instance.students.where((c) => c.id == student.id);
    if (found.isEmpty) {
      _snack('Student not found. Please try again.');
      return;
    }
    final previous = found.first;

    final updated = await showModalBottomSheet<ChildInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          AddStudentSheet(nextRoll: previous.rollNo, existing: previous),
    );
    if (updated == null || !mounted) return;

    try {
      await AppState.instance.updateStudent(updated, previous: previous);
      if (!mounted) return;
      final newMail = updated.parentEmail.trim().toLowerCase();
      final mailChanged =
          previous.parentEmail.trim().toLowerCase() != newMail;
      _snack(
        mailChanged
            ? '${updated.name} updated. Old parent login removed; '
            'new parent can login with $newMail'
            : '${updated.name} updated.',
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Could not update student: $e');
    }
  }

  Future<void> _confirmRemove(_Student student) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove student?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '${student.name} will be removed from the class. '
              'The parent will no longer be able to see this child.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AppState.instance.deleteStudent(student.id);
    } catch (e) {
      if (!mounted) return;
      _snack('Could not remove student: $e');
    }
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

// =====================================================================
// ADD STUDENT SHEET
// =====================================================================
class AddStudentSheet extends StatefulWidget {
  const AddStudentSheet({required this.nextRoll, this.existing});

  final int nextRoll;

  /// null = नवीन विद्यार्थी जोडणे; नाहीतर या विद्यार्थ्याची माहिती edit करणे.
  final ChildInfo? existing;

  @override
  State<AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends State<AddStudentSheet> {
  static const Color dark = Color(0xFF183B45);
  static const Color primary = Color(0xFF168C80);
  static const Color muted = Color(0xFF84918D);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _roll = TextEditingController();
  final _parent = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _allergy = TextEditingController();

  DateTime? _dob;
  String _gender = 'Boy';
  String? _blood;

  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
  ];

  bool get _isEdit => widget.existing != null;

  /// Edit करताना parent email बदलला का (जुन्या parent चं login निघून जातं).
  bool get _emailChanged =>
      _isEdit &&
          _email.text.trim().toLowerCase() !=
              widget.existing!.parentEmail.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) {
      _roll.text = '${widget.nextRoll}';
    } else {
      _name.text = e.name;
      _roll.text = '${e.rollNo}';
      _parent.text = e.parentName;
      _email.text = e.parentEmail;
      _phone.text = e.contacts.isNotEmpty ? e.contacts.first.phone : '';
      _allergy.text = e.allergyNote;
      _dob = e.dob;
      _gender = e.gender == 'Girl' ? 'Girl' : 'Boy';
      _blood = _bloodGroups.contains(e.bloodGroup) ? e.bloodGroup : null;
      // email बदलला की खाली warning दाखवण्यासाठी.
      _email.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    _parent.dispose();
    _email.dispose();
    _phone.dispose();
    _allergy.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF4F9F8),
    isDense: true,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 3, 1, 1);
    final earliest = DateTime(now.year - 10);
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      // जुनी dob 10 वर्षांपेक्षा जुनी असली तरी picker crash होत नाही.
      firstDate: initial.isBefore(earliest) ? initial : earliest,
      lastDate: now,
    );
    if (d != null) setState(() => _dob = d);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phone.text.trim();
    final e = widget.existing;

    // Edit करताना बाकीचे contacts (आई/बाबा/आजी...) पुसले जाऊ नयेत.
    final contacts = <ParentContact>[...(e?.contacts ?? const <ParentContact>[])];
    if (phone.isNotEmpty) {
      if (contacts.isEmpty) {
        contacts.add(ParentContact(_parent.text.trim(), 'Parent', phone));
      } else {
        final c0 = contacts.first;
        contacts[0] = ParentContact(
          c0.name.isEmpty ? _parent.text.trim() : c0.name,
          c0.relation.isEmpty ? 'Parent' : c0.relation,
          phone,
        );
      }
    } else if (contacts.isNotEmpty) {
      contacts.removeAt(0);
    }

    Navigator.pop(
      context,
      ChildInfo(
        id: e?.id ?? '',
        name: _name.text.trim(),
        // नवीन: AppState.addStudent() class चं नाव स्वतः भरतो; Edit: आधीचं तेच.
        className: e?.className ?? '',
        classId: e?.classId ?? '',
        rollNo: int.tryParse(_roll.text.trim()) ?? widget.nextRoll,
        dob: _dob ?? DateTime(DateTime.now().year - 3, 1, 1),
        bloodGroup: _blood ?? '',
        gender: _gender,
        allergyNote: _allergy.text.trim(),
        parentName: _parent.text.trim(),
        parentEmail: _email.text.trim().toLowerCase(),
        pickupNote: e?.pickupNote ?? '',
        contacts: contacts,
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
                  _isEdit ? 'Edit student' : 'Add student',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isEdit
                      ? 'Update the details and tap Save changes.'
                      : 'Parent can login with the email you enter here.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Student name'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter student name'
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _roll,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _dec('Roll no'),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _pickDob,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: _dec('Date of birth'),
                          child: Text(
                            _dob == null
                                ? 'Select'
                                : '${_dob!.day} ${AppState.monthShort(_dob!.month)} ${_dob!.year}',
                            style: TextStyle(
                              fontSize: 14,
                              color: _dob == null ? muted : dark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final g in const ['Boy', 'Girl']) ...[
                      ChoiceChip(
                        label: Text(g),
                        selected: _gender == g,
                        showCheckmark: false,
                        selectedColor: primary,
                        backgroundColor: const Color(0xFFE4F3EF),
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _gender == g ? Colors.white : primary,
                        ),
                        onSelected: (_) => setState(() => _gender = g),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const SizedBox(width: 4),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _blood,
                        decoration: _dec('Blood group'),
                        items: [
                          for (final b in _bloodGroups)
                            DropdownMenuItem(value: b, child: Text(b)),
                        ],
                        onChanged: (v) => setState(() => _blood = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _parent,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Parent name'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter parent name'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('Parent email (used for login)'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
                    return ok ? null : 'Enter a valid email';
                  },
                ),
                if (_emailChanged) ...[
                  const SizedBox(height: 6),
                  const Text(
                    "Changing the email removes the old parent's login. "
                        'The new email can login right away.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFFD99437),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: _dec('Parent phone (optional)'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _allergy,
                  decoration: _dec('Allergy / medical note (optional)'),
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
                      _isEdit ? 'Save changes' : 'Add student',
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