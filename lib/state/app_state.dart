import 'package:flutter/foundation.dart';

// =====================================================================
// SHARED MODELS  (Teacher app आणि Parent app दोघेही हेच वापरतात)
// =====================================================================

class CircularRecord {
  const CircularRecord({
    required this.title,
    required this.audience,
    required this.category,
    required this.families,
    required this.sentAt,
    this.eventDate,
    this.attachment,
    this.message = '',
    this.important = false,
    this.scheduledFor,
    this.needsAck = false,
  });

  final String title;
  final String audience;
  final String category;
  final int families;
  final DateTime sentAt;
  final DateTime? eventDate;
  final String? attachment;

  // --- नवीन: parent ला दाखवण्यासाठी ---
  final String message;
  final bool important;
  final DateTime? scheduledFor;

  // --- FIX 7: Parent ने "मी वाचलं" confirm करावं का? ---
  final bool needsAck;
}

class SharedPhoto {
  const SharedPhoto(this.colorIndex, this.tags);
  final int colorIndex;
  final List<String> tags; // tagged children ची नावे
}

class PhotoBatch {
  PhotoBatch({
    required this.photos,
    required this.caption,
    required this.wholeClass,
    required this.sentAt,
  });

  final List<SharedPhoto> photos;
  final String caption;
  final bool wholeClass; // true = संपूर्ण class ला पाठवलेले
  final DateTime sentAt;
}

class DiaryLine {
  const DiaryLine(this.label, this.text);
  final String label; // Rhyme / Letter / Number / Colour / Activity ...
  final String text;
}

class DiaryPost {
  DiaryPost({
    required this.date,
    required this.items,
    this.mood,
    this.homeNote = '',
    this.bring = const [],
    required this.publishedAt,
  });

  final DateTime date;
  final List<DiaryLine> items;
  final String? mood;
  final String homeNote;
  final List<String> bring;
  final DateTime publishedAt;
}

class ChatMessage {
  const ChatMessage(this.text, this.fromTeacher, this.time);
  final String text;
  final bool fromTeacher;
  final String time;
}

class ParentContact {
  const ParentContact(this.name, this.relation, this.phone);
  final String name;
  final String relation;
  final String phone;
}

class ChildInfo {
  ChildInfo({
    required this.name,
    required this.className,
    required this.rollNo,
    required this.dob,
    required this.bloodGroup,
    required this.gender,
    required this.allergyNote,
    required this.parentName,
    required this.contacts,
    required this.pickupNote,
  });

  final String name;
  final String className;
  final int rollNo;
  final DateTime dob;
  final String bloodGroup;
  final String gender;
  final String allergyNote;
  final String parentName;
  final List<ParentContact> contacts;
  final String pickupNote;

  String get firstName => name.split(' ').first;
  String get parentFirstName => parentName.split(' ').first;

  /// Teacher ने photo वर tag केलेले नाव या मुलाचे आहे का?
  bool matches(Iterable<String> tags) =>
      tags.any((t) => t.toLowerCase().contains(firstName.toLowerCase()));

  String ageLabel(DateTime now) {
    var y = now.year - dob.year;
    var m = now.month - dob.month;
    if (now.day < dob.day) m--;
    if (m < 0) {
      y--;
      m += 12;
    }
    return '${y}y ${m}m';
  }
}

enum FeeStatus { paid, due, upcoming }

class FeeItem {
  const FeeItem(this.title, this.amount, this.status, this.dueDate);
  final String title;
  final int amount;
  final FeeStatus status;
  final DateTime? dueDate;
}

class FeeReceipt {
  const FeeReceipt(this.title, this.amount, this.date, this.mode);
  final String title;
  final int amount;
  final DateTime date;
  final String mode;
}

class SchoolEvent {
  const SchoolEvent({
    required this.date,
    required this.title,
    required this.category,
    this.note = '',
  });
  final DateTime date;
  final String title;
  final String category; // Holiday / Meeting / Event / Celebration
  final String note;
}

// =====================================================================
// APP STATE  (Teacher + Parent दोघांचा common data)
// Firebase आल्यावर फक्त हा file बदलायचा, screens तसेच राहतील.
// =====================================================================
class AppState extends ChangeNotifier {
  AppState._() {
    _seed();
  }
  static final AppState instance = AppState._();

  // ---------- Teacher side (जुना data) ----------
  final String teacherName = 'Ms. Kavya';
  final String className = 'Nursery A';
  final int totalChildren = 22;
  final int totalFamilies = 86;

  bool attendanceSaved = false;
  int presentCount = 0;
  int absentCount = 0;
  int photosToday = 0;
  bool diaryPublished = false;
  int unreadMessages = 3;
  final List<CircularRecord> circulars = [];

  // ---------- Shared data (Parent app हे वाचतो) ----------
  late ChildInfo child;
  Map<String, String?> attendanceStatuses = {};
  List<PhotoBatch> photoBatches = [];
  List<DiaryPost> diaryPosts = [];
  List<CircularRecord> _schoolCirculars = [];
  final Set<CircularRecord> readCirculars = {};
  // FIX 7: ज्या circulars ना Parent ने acknowledge केलं
  final Set<CircularRecord> ackedCirculars = {};
  List<SchoolEvent> _extraEvents = [];
  List<FeeItem> fees = [];
  List<FeeReceipt> receipts = [];
  final Map<String, List<ChatMessage>> _threads = {};

  void _seed() {
    final now = DateTime.now();
    DateTime ago(int d, [int h = 11]) =>
        DateTime(now.year, now.month, now.day - d, h);
    DateTime ahead(int d) => DateTime(now.year, now.month, now.day + d);

    child = ChildInfo(
      name: 'Aarav Mehta',
      className: 'Nursery A',
      rollNo: 4,
      dob: DateTime(2023, 8, 14),
      bloodGroup: 'B+',
      gender: 'Boy',
      allergyNote:
      'Allergic to peanuts. Uses inhaler if needed — kept in school bag.',
      parentName: 'Priya Mehta',
      contacts: const [
        ParentContact('Priya Mehta', 'Mother', '98765 43210'),
        ParentContact('Rajesh Mehta', 'Father', '98220 11223'),
      ],
      pickupNote: 'Also picks up: Sunita Iyer (Grandmother)',
    );

    photoBatches = [
      PhotoBatch(
        photos: const [
          SharedPhoto(0, ['Aarav Mehta']),
          SharedPhoto(1, ['Aarav Mehta']),
        ],
        caption: 'Rhyme time',
        wholeClass: false,
        sentAt: ago(1),
      ),
      PhotoBatch(
        photos: const [
          SharedPhoto(2, ['Aarav Mehta']),
          SharedPhoto(3, ['Aarav Mehta']),
          SharedPhoto(0, ['Aarav Mehta']),
        ],
        caption: 'Art & craft',
        wholeClass: false,
        sentAt: ago(2),
      ),
      PhotoBatch(
        photos: const [
          SharedPhoto(1, []),
          SharedPhoto(2, []),
          SharedPhoto(3, []),
          SharedPhoto(0, []),
        ],
        caption: 'Class picnic',
        wholeClass: true,
        sentAt: ago(3),
      ),
    ];

    diaryPosts = [
      DiaryPost(
        date: ago(1),
        items: const [
          DiaryLine('Rhyme', 'Johny Johny Yes Papa'),
          DiaryLine('Letter', 'B — Ball, Bat'),
          DiaryLine('Number', 'Counting 1 to 3'),
          DiaryLine('Colour', 'Blue'),
          DiaryLine('Activity', 'Paper boat making'),
        ],
        mood: 'Happy',
        homeNote: 'Please practise counting 1 to 3 at home.',
        bring: const ['Crayons'],
        publishedAt: ago(1, 12),
      ),
      DiaryPost(
        date: ago(2),
        items: const [
          DiaryLine('Rhyme', 'Humpty Dumpty'),
          DiaryLine('Letter', 'A — Apple, Ant'),
          DiaryLine('Activity', 'Clay play'),
        ],
        mood: 'Energetic',
        homeNote: '',
        bring: const [],
        publishedAt: ago(2, 12),
      ),
    ];

    _schoolCirculars = [
      CircularRecord(
        title: 'Annual day costume',
        audience: 'All parents',
        category: 'Event',
        families: 86,
        sentAt: ago(4),
        attachment: 'costume_details.pdf',
        message:
        'Costume details for the annual day dance are attached. '
            'Please arrange the costume before the practice week.',
      ),
      CircularRecord(
        title: 'Parent-teacher meeting',
        audience: 'Nursery A',
        category: 'Meeting',
        families: 22,
        sentAt: ago(2),
        eventDate: ahead(6),
        message:
        'Parent-teacher meeting at 10:00 AM in the Nursery A classroom. '
            'Please attend with both parents if possible.',
      ),
      CircularRecord(
        title: 'School holiday notice',
        audience: 'All parents',
        category: 'Holiday',
        families: 86,
        sentAt: ago(1),
        eventDate: ahead(2),
        important: true,
        message:
        'School will remain closed on the mentioned date. '
            'Classes resume on the next working day.',
      ),
    ];

    _extraEvents = [
      SchoolEvent(
        date: ahead(10),
        title: 'Sports day',
        category: 'Event',
        note: 'Wear house T-shirt',
      ),
      SchoolEvent(
        date: ahead(15),
        title: 'Annual day practice',
        category: 'Celebration',
        note: 'Costume required',
      ),
    ];

    fees = [
      FeeItem('Admission fee', 5000, FeeStatus.paid, null),
      FeeItem('Term 1 fee', 6000, FeeStatus.paid, null),
      FeeItem('Term 2 fee', 6000, FeeStatus.due, ahead(24)),
      FeeItem('Term 3 fee', 6000, FeeStatus.upcoming, ahead(115)),
    ];

    receipts = [
      FeeReceipt('Term 1', 6000, DateTime(now.year, 7, 10), 'UPI'),
      FeeReceipt('Admission', 5000, DateTime(now.year, 6, 25), 'Cash'),
    ];

    _threads.clear();
    _threads['Priya Mehta'] = const [
      ChatMessage(
          'Good morning ma’am, Aarav has a mild cold today. '
              'Please keep an eye on him.',
          false,
          '9:14 AM'),
      ChatMessage(
          'Sure, thank you for informing. I will make sure he drinks water.',
          true,
          '12:10 PM'),
      ChatMessage(
          'He was cheerful in class and enjoyed the rhyme today.',
          true,
          '12:11 PM'),
      ChatMessage('Thank you ma’am!', false, '12:20 PM'),
    ].toList();
  }

  /// Demo data परत सुरुवातीला आणण्यासाठी (logout / testing).
  void reset() {
    attendanceSaved = false;
    presentCount = 0;
    absentCount = 0;
    photosToday = 0;
    diaryPublished = false;
    unreadMessages = 3;
    circulars.clear();
    readCirculars.clear();
    ackedCirculars.clear();
    attendanceStatuses = {};
    _seed();
    notifyListeners();
  }

  // =================================================================
  // TEACHER ACTIONS  (जुन्या calls तशाच चालतात; नवीन params optional)
  // =================================================================
  void saveAttendance({
    required int present,
    required int absent,
    Map<String, String?>? statuses,
  }) {
    attendanceSaved = true;
    presentCount = present;
    absentCount = absent;
    if (statuses != null) attendanceStatuses = statuses;
    notifyListeners();
  }

  void addPhotos(
      int count, {
        List<SharedPhoto>? photos,
        String caption = '',
        bool wholeClass = false,
      }) {
    photosToday += count;
    final list = (photos != null && photos.isNotEmpty)
        ? photos
        : List.generate(count, (i) => SharedPhoto(i % 4, [child.name]));
    photoBatches.insert(
      0,
      PhotoBatch(
        photos: list,
        caption: caption,
        wholeClass: wholeClass,
        sentAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void publishDiary({
    List<DiaryLine>? items,
    String? mood,
    String? homeNote,
    List<String>? bring,
  }) {
    diaryPublished = true;
    final now = DateTime.now();
    diaryPosts.removeWhere((p) => _sameDay(p.date, now));
    diaryPosts.insert(
      0,
      DiaryPost(
        date: now,
        items: items ??
            const [
              DiaryLine('Rhyme', 'Twinkle Twinkle Little Star'),
              DiaryLine('Letter', 'A — Apple, Ant'),
              DiaryLine('Number', 'Counting 1 to 5'),
              DiaryLine('Colour', 'Red'),
              DiaryLine('Activity', 'Colouring an apple'),
            ],
        mood: mood,
        homeNote: homeNote ?? '',
        bring: bring ?? const [],
        publishedAt: now,
      ),
    );
    notifyListeners();
  }

  void addCircular(CircularRecord record) {
    circulars.insert(0, record);
    notifyListeners();
  }

  void markRead(int count) {
    unreadMessages = (unreadMessages - count).clamp(0, 999);
    notifyListeners();
  }

  // =================================================================
  // CHAT  (Teacher ↔ Parent एकच thread)
  // =================================================================
  List<ChatMessage> thread(String parentName,
      {String? seed, String seedTime = ''}) {
    return _threads.putIfAbsent(
      parentName,
          () => [ChatMessage(seed ?? 'Hello teacher!', false, seedTime)],
    );
  }

  void sendMessage(String parentName, String text,
      {required bool fromTeacher}) {
    thread(parentName).add(
      ChatMessage(text, fromTeacher, timeLabel(DateTime.now())),
    );
    if (!fromTeacher) unreadMessages += 1; // parent ने पाठवले → teacher badge
    notifyListeners();
  }

  // =================================================================
  // PARENT READ HELPERS
  // =================================================================
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool sameDay(DateTime a, DateTime b) => _sameDay(a, b);

  /// 'P' / 'L' / 'A' किंवा '' (अजून mark नाही)
  String get childAttendanceCode {
    if (!attendanceSaved) return '';
    for (final e in attendanceStatuses.entries) {
      if (child.matches([e.key])) return e.value ?? '';
    }
    return attendanceStatuses.isEmpty ? 'P' : '';
  }

  List<SharedPhoto> childPhotosOn(DateTime day) {
    final out = <SharedPhoto>[];
    for (final b in photoBatches) {
      if (_sameDay(b.sentAt, day)) {
        out.addAll(b.photos.where((p) => child.matches(p.tags)));
      }
    }
    return out;
  }

  DiaryPost? diaryFor(DateTime day) {
    for (final p in diaryPosts) {
      if (_sameDay(p.date, day)) return p;
    }
    return null;
  }

  /// Parent ला दिसणारे circulars (scheduled भविष्यातले वगळून), नवीन आधी.
  List<CircularRecord> get visibleCirculars {
    final now = DateTime.now();
    final all = [...circulars, ..._schoolCirculars]
        .where((c) => c.scheduledFor == null || !c.scheduledFor!.isAfter(now))
        .toList();
    all.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return all;
  }

  bool isNewCircular(CircularRecord c) =>
      !readCirculars.contains(c) &&
          DateTime.now().difference(c.sentAt).inDays < 3;

  int get unreadCircularCount =>
      visibleCirculars.where(isNewCircular).length;

  void markCircularRead(CircularRecord c) {
    if (readCirculars.add(c)) notifyListeners();
  }

  // FIX 7: Acknowledgement
  bool isAcked(CircularRecord c) => ackedCirculars.contains(c);

  /// Parent ने "I have read this" दाबलं. Circular आपोआप "read" सुद्धा होतं.
  void acknowledgeCircular(CircularRecord c) {
    readCirculars.add(c);
    if (ackedCirculars.add(c)) notifyListeners();
  }

  /// Teacher साठी: acknowledgement बाकी असलेल्या circulars ची संख्या.
  int get pendingAckCount => visibleCirculars
      .where((c) => c.needsAck && !ackedCirculars.contains(c))
      .length;

  FeeItem? get nextDueFee {
    for (final f in fees) {
      if (f.status == FeeStatus.due) return f;
    }
    return null;
  }

  /// Calendar events = school extra events + circulars ज्यांना event date आहे.
  List<SchoolEvent> get events {
    final list = <SchoolEvent>[..._extraEvents];
    for (final c in visibleCirculars) {
      if (c.eventDate != null) {
        list.add(SchoolEvent(
          date: c.eventDate!,
          title: c.title,
          category: c.category == 'Notice' ? 'Event' : c.category,
          note: firstLine(c.message),
        ));
      }
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<SchoolEvent> eventsOn(DateTime day) =>
      events.where((e) => _sameDay(e.date, day)).toList();

  static String firstLine(String text, [int max = 48]) {
    final t = text.trim().split('\n').first;
    return t.length <= max ? t : '${t.substring(0, max - 1)}…';
  }

  // ---------- Date / time helpers ----------
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _monthsFull = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String dateLabel(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

  static String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String monthName(int month) => _monthsFull[month - 1];

  static String monthShort(int month) => _months[month - 1];

  /// 'Mon 5' (diary date chips साठी)
  static String chipDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day}';

  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'Today';
    if (_sameDay(d, DateTime(now.year, now.month, now.day - 1))) {
      return 'Yesterday';
    }
    return shortDate(d);
  }

  static String timeLabel(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}