import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

// =====================================================================
// SHARED MODELS  (Teacher app आणि Parent app दोघेही हेच वापरतात)
// ---------------------------------------------------------------------
// बदल: प्रत्येक model ला Firestore `id` + fromMap/toMap जोडले आहेत.
// जुने constructors तसेच आहेत (नवीन fields optional) त्यामुळे
// जुने screens compile होतात.
// =====================================================================

DateTime? _dt(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

class CircularRecord {
  const CircularRecord({
    this.id = '',
    required this.title,
    required this.audience,
    required this.category,
    required this.families,
    required this.sentAt,
    this.eventDate,
    this.attachment,
    this.attachmentUrl,
    this.message = '',
    this.important = false,
    this.scheduledFor,
    this.needsAck = false,
    this.readBy = const [],
    this.ackedBy = const [],
  });

  final String id;
  final String title;
  final String audience;
  final String category;
  final int families;
  final DateTime sentAt;
  final DateTime? eventDate;
  final String? attachment;

  /// Firebase Storage चा download link (नसेल तर parent ला फक्त नाव दिसतं).
  final String? attachmentUrl;
  final String message;
  final bool important;
  final DateTime? scheduledFor;
  final bool needsAck;

  /// ज्या students च्या parents नी वाचलं / acknowledge केलं (studentId list)
  final List<String> readBy;
  final List<String> ackedBy;

  // Firestore मध्ये id असल्यामुळे नवीन snapshot आला तरी Set.contains चालतं.
  @override
  bool operator ==(Object other) =>
      other is CircularRecord &&
          (id.isNotEmpty ? other.id == id : identical(this, other));

  @override
  int get hashCode => id.isNotEmpty ? id.hashCode : identityHashCode(this);

  factory CircularRecord.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return CircularRecord(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      audience: (d['audience'] ?? '') as String,
      category: (d['category'] ?? 'Notice') as String,
      families: (d['families'] ?? 0) as int,
      sentAt: _dt(d['sentAt']) ?? DateTime.now(),
      eventDate: _dt(d['eventDate']),
      attachment: d['attachment'] as String?,
      attachmentUrl: d['attachmentUrl'] as String?,
      message: (d['message'] ?? '') as String,
      important: (d['important'] ?? false) as bool,
      scheduledFor: _dt(d['scheduledFor']),
      needsAck: (d['needsAck'] ?? false) as bool,
      readBy: List<String>.from(d['readBy'] ?? const []),
      ackedBy: List<String>.from(d['ackedBy'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'audience': audience,
    'category': category,
    'families': families,
    'sentAt': Timestamp.fromDate(sentAt),
    'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate!),
    'attachment': attachment,
    'attachmentUrl': attachmentUrl,
    'message': message,
    'important': important,
    'scheduledFor':
    scheduledFor == null ? null : Timestamp.fromDate(scheduledFor!),
    'needsAck': needsAck,
    'readBy': <String>[],
    'ackedBy': <String>[],
  };
}

class SharedPhoto {
  const SharedPhoto(this.colorIndex, this.tags, {this.url, this.bytes});
  final int colorIndex;
  final List<String> tags; // tagged children ची नावे
  final String? url; // Firebase Storage download URL

  /// Teacher ने निवडलेल्या फोटोचे bytes (upload होण्यापूर्वी). Firestore मध्ये जात नाही.
  final Uint8List? bytes;
}

class PhotoBatch {
  PhotoBatch({
    required this.photos,
    required this.caption,
    required this.wholeClass,
    required this.sentAt,
    this.batchId = '',
  });

  /// Firestore मधील batchId (delete करण्यासाठी वापरतो).
  final String batchId;

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
  const ChatMessage(this.text, this.fromTeacher, this.time,
      {this.id = '', this.at, this.image = ''});
  final String id;
  final String text;
  final bool fromTeacher;
  final String time;
  final DateTime? at;

  /// NEW: फोटो असलेला message – 'data:image/jpeg;base64,...' (नसेल तर '').
  final String image;

  bool get hasImage => image.isNotEmpty;

  /// फोटोसोबत caption नसेल तर हा default मजकूर साठवला जातो.
  bool get isPhotoOnly => hasImage && text == AppState.photoMessageText;
}

/// Teacher च्या Messages list साठी: प्रत्येक मुलाच्या thread ची summary.
class ThreadMeta {
  const ThreadMeta({
    required this.studentId,
    required this.studentName,
    required this.parentName,
    required this.lastText,
    required this.lastAt,
    required this.teacherUnread,
  });

  final String studentId;
  final String studentName;
  final String parentName;
  final String lastText;
  final DateTime? lastAt;
  final int teacherUnread;
}

class ParentContact {
  const ParentContact(this.name, this.relation, this.phone);
  final String name;
  final String relation;
  final String phone;

  Map<String, dynamic> toMap() =>
      {'name': name, 'relation': relation, 'phone': phone};
}

class ChildInfo {
  ChildInfo({
    this.id = '',
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
    this.parentEmail = '',
    this.classId = '',
    this.facePhoto = '',
  });

  /// Firestore load होण्यापूर्वी (किंवा parent link नसताना) वापरला जाणारा रिकामा child.
  factory ChildInfo.empty() => ChildInfo(
    name: '',
    className: '',
    rollNo: 0,
    dob: DateTime(2022, 1, 1),
    bloodGroup: '',
    gender: '',
    allergyNote: '',
    parentName: '',
    contacts: const [],
    pickupNote: '',
  );

  factory ChildInfo.fromMap(String id, Map<String, dynamic> d) {
    final rawContacts = (d['contacts'] ?? const []) as List;
    return ChildInfo(
      id: id,
      name: (d['name'] ?? '') as String,
      className: (d['className'] ?? '') as String,
      rollNo: (d['rollNo'] ?? 0) as int,
      dob: _dt(d['dob']) ?? DateTime(2022, 1, 1),
      bloodGroup: (d['bloodGroup'] ?? '') as String,
      gender: (d['gender'] ?? '') as String,
      allergyNote: (d['allergyNote'] ?? '') as String,
      parentName: (d['parentName'] ?? '') as String,
      parentEmail: (d['parentEmail'] ?? '') as String,
      classId: (d['classId'] ?? '') as String,
      facePhoto: (d['facePhoto'] ?? '') as String,
      pickupNote: (d['pickupNote'] ?? '') as String,
      contacts: [
        for (final c in rawContacts)
          ParentContact(
            ((c as Map)['name'] ?? '') as String,
            (c['relation'] ?? '') as String,
            (c['phone'] ?? '') as String,
          ),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'className': className,
    'rollNo': rollNo,
    'dob': Timestamp.fromDate(dob),
    'bloodGroup': bloodGroup,
    'gender': gender,
    'allergyNote': allergyNote,
    'parentName': parentName,
    'parentEmail': parentEmail.trim().toLowerCase(),
    'classId': classId,
    'pickupNote': pickupNote,
    'contacts': [for (final c in contacts) c.toMap()],
    // नवीन: AI attendance scan साठी मुलाचा एक चेहऱ्याचा फोटो (base64).
    // रिकामा असेल तर पाठवत नाही, म्हणजे Teacher ने edit केल्यावर तो पुसला जात नाही.
    if (facePhoto.isNotEmpty) 'facePhoto': facePhoto,
  };

  final String id;
  final String name;
  final String className;
  final int rollNo;
  final DateTime dob;
  final String bloodGroup;
  final String gender;
  final String allergyNote;
  final String parentName;
  final String parentEmail;
  final String classId;
  final List<ParentContact> contacts;
  final String pickupNote;

  /// 'data:image/jpeg;base64,...' — AI scan साठी reference face photo (नसेल तर '').
  final String facePhoto;

  String get firstName => name.split(' ').first;
  String get parentFirstName => parentName.split(' ').first;

  /// Teacher ने photo वर tag केलेले नाव या मुलाचे आहे का?
  bool matches(Iterable<String> tags) {
    if (firstName.isEmpty) return false;
    final me = firstName.trim().toLowerCase();
    // पूर्ण नाव जुळलं पाहिजे ('Ana' tag मुळे 'Anaya' च्या parent ला फोटो दिसू नये).
    return tags.any((t) => t.trim().toLowerCase() == me);
  }

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

/// Parent साठी: मुलाच्या एका दिवसाची हजेरी (P = Present, L = Late, A = Absent).
class AttendanceDay {
  const AttendanceDay(this.date, this.status, this.reason);
  final DateTime date;
  final String status;
  final String reason;
}

enum FeeStatus { paid, due, upcoming }

class FeeItem {
  const FeeItem(this.title, this.amount, this.status, this.dueDate,
      {this.id = ''});
  final String id;
  final String title;
  final int amount;
  final FeeStatus status;
  final DateTime? dueDate;
}

class FeeReceipt {
  const FeeReceipt(this.title, this.amount, this.date, this.mode,
      {this.id = '', this.feeId = ''});
  final String id;

  /// कोणत्या fee ची ही receipt (title वरून अंदाज लावण्याऐवजी खरा link).
  final String feeId;
  final String title;
  final int amount;
  final DateTime date;
  final String mode;
}

/// Parent ने पाठवलेला रजेचा अर्ज (Teacher approve / decline करतो).
class LeaveRequest {
  const LeaveRequest({
    this.id = '',
    required this.studentId,
    required this.studentName,
    required this.parentName,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = 'pending',
    this.teacherNote = '',
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String parentName;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;

  /// 'pending' | 'approved' | 'declined'
  final String status;
  final String teacherNote;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';

  int get days => toDate.difference(fromDate).inDays + 1;
}

class SchoolEvent {
  const SchoolEvent({
    this.id = '',
    required this.date,
    required this.title,
    required this.category,
    this.note = '',
  });
  final String id;
  final DateTime date;
  final String title;
  final String category; // Holiday / Meeting / Event / Celebration
  final String note;
}

// =====================================================================
// APP STATE  (Teacher + Parent दोघांचा common data)
// ---------------------------------------------------------------------
// आता सगळा data Firebase Firestore मधून येतो (dummy/seed data काढला).
// Teacher app मध्ये save केलेला data Parent app ला Firestore मार्फत
// real-time दिसतो.
//
// वापर:
//   login नंतर:  await AppState.instance.startSession();
//   logout:      await AppState.instance.endSession();
// =====================================================================
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final List<StreamSubscription<dynamic>> _subs = [];

  // ---------- Session ----------
  String uid = '';
  String role = ''; // 'teacher' | 'parent'
  String classId = '';
  String schoolName = '';
  bool ready = false; // session सुरू होऊन पहिला data आला का
  String? lastError;

  bool get isTeacher => role == 'teacher';
  bool get isParent => role == 'parent';

  // ---------- Teacher side ----------
  String teacherName = 'Teacher';
  String className = '';

  /// Class मधील मुलांची संख्या (Firestore students मधून).
  int get totalChildren => students.length;

  /// प्रत्येक मुलाचं एक family धरलं आहे.
  int get totalFamilies => students.length;

  bool attendanceSaved = false;
  int presentCount = 0;
  int absentCount = 0;

  int get photosToday {
    final now = DateTime.now();
    var n = 0;
    for (final b in photoBatches) {
      if (_sameDay(b.sentAt, now)) n += b.photos.length;
    }
    return n;
  }

  bool get diaryPublished => diaryFor(DateTime.now()) != null;

  /// Teacher: सर्व threads मधले unread parent messages.
  /// Parent: teacher चे unread messages.
  int get unreadMessages {
    if (isParent) return _myThreadMeta?.parentUnreadCount ?? 0;
    var n = 0;
    for (final m in _threadMetas.values) {
      n += m.teacherUnread;
    }
    return n;
  }

  // ---------- Shared data ----------
  ChildInfo child = ChildInfo.empty();

  /// Teacher: class चे सर्व students (rollNo नुसार).
  List<ChildInfo> students = [];

  /// 'studentId' -> 'P' / 'A' / 'L'  (आजचा attendance)
  Map<String, String?> attendanceStatuses = {};
  Map<String, String> attendanceReasons = {};
  List<_AttRow> _weekRows = [];

  /// Parent: मुलाची आतापर्यंतची सर्व हजेरी (नवीन दिवस आधी).
  List<AttendanceDay> attendanceHistory = [];

  List<PhotoBatch> photoBatches = [];
  List<DiaryPost> diaryPosts = [];
  List<CircularRecord> circulars = [];
  final Set<String> _pendingRead = {};
  final Set<String> _pendingAck = {};
  List<SchoolEvent> _extraEvents = [];
  List<FeeItem> fees = [];
  List<FeeReceipt> receipts = [];

  /// Leave अर्ज: Teacher ला class चे सर्व, Parent ला फक्त स्वतःच्या मुलाचे.
  List<LeaveRequest> leaves = [];

  final Map<String, List<ChatMessage>> _threads = {};
  final Map<String, StreamSubscription<dynamic>> _threadSubs = {};
  final Map<String, ThreadMeta> _threadMetas = {};
  _ParentThreadMeta? _myThreadMeta;

  // =================================================================
  // SESSION
  // =================================================================
  CollectionReference<Map<String, dynamic>> _classCol(String name) =>
      _db.collection('classes').doc(classId).collection(name);

  /// Login / app उघडल्यावर call करा. यशस्वी झाल्यास null, नाहीतर error text.
  Future<String?> startSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Please login first.';

    await _cancelAll();
    try {
      final udoc = await _db.collection('users').doc(user.uid).get();
      if (!udoc.exists) return 'Profile not found. Please register again.';
      final u = udoc.data()!;

      final pendingRole = (u['role'] ?? '') as String;
      if (pendingRole == 'teacher' && u['approved'] == false) {
        return 'Your account is waiting for Admin approval. '
            'Please try again after the school approves you.';
      }

      uid = user.uid;
      role = pendingRole;
      classId = (u['classId'] ?? '') as String;

      if (role == 'teacher') {
        await _ensureClassDoc(u);
        teacherName = (u['name'] ?? 'Teacher') as String;
        className = (u['className'] ?? '') as String;
        schoolName = (u['schoolName'] ?? '') as String;
        _startTeacher();
      } else if (role == 'parent') {
        final studentId = (u['studentId'] ?? '') as String;
        if (studentId.isEmpty) return 'No student linked to this parent.';
        await _startParent(studentId);
      } else if (role == 'admin') {
        return 'This is an Admin account. Please use the web admin panel.';
      } else {
        return 'Unknown role.';
      }
      ready = true;
      notifyListeners();
      return null;
    } catch (e) {
      lastError = '$e';
      // बदल: Parent चा access गेला असेल (teacher/admin ने email बदलला किंवा
      // विद्यार्थी delete केला) तर raw Firestore error ऐवजी स्पष्ट संदेश.
      if (role == 'parent') {
        await _cancelAll();
        if (e is FirebaseException && e.code == 'permission-denied') {
          return 'This email is no longer linked to a student. '
              'Please ask the teacher or school office to check your email.';
        }
        if (e is String) {
          return '$e Please ask the teacher or school office.';
        }
      }
      return 'Could not load data: $e';
    }
  }

  /// Approve नंतर `classes/{classId}` नसेल तर बनवतो (Parent app ला teacher/class नाव दिसावं म्हणून).
  Future<void> _ensureClassDoc(Map<String, dynamic> u) async {
    if (classId.isEmpty) return;
    try {
      final ref = _db.collection('classes').doc(classId);
      final snap = await ref.get();
      if (snap.exists) return;
      await ref.set({
        'teacherName': (u['name'] ?? '') as String,
        'className': (u['className'] ?? '') as String,
        'schoolName': (u['schoolName'] ?? '') as String,
        'teacherUid': uid,
      }, SetOptions(merge: true));
    } catch (e) {
      lastError = '$e';
    }
  }

  Future<void> endSession() async {
    await _cancelAll();
    uid = '';
    role = '';
    classId = '';
    schoolName = '';
    ready = false;
    teacherName = 'Teacher';
    className = '';
    child = ChildInfo.empty();
    students = [];
    attendanceSaved = false;
    presentCount = 0;
    absentCount = 0;
    attendanceStatuses = {};
    attendanceReasons = {};
    _weekRows = [];
    attendanceHistory = [];
    photoBatches = [];
    diaryPosts = [];
    circulars = [];
    _pendingRead.clear();
    _pendingAck.clear();
    _extraEvents = [];
    fees = [];
    receipts = [];
    leaves = [];
    _threads.clear();
    _threadMetas.clear();
    _myThreadMeta = null;
    notifyListeners();
  }

  Future<void> _cancelAll() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final s in _threadSubs.values) {
      await s.cancel();
    }
    _threadSubs.clear();
  }

  void _listen(
      Query<Map<String, dynamic>> q,
      void Function(QuerySnapshot<Map<String, dynamic>> snap) onData,
      ) {
    _subs.add(q.snapshots().listen(
          (snap) {
        onData(snap);
        notifyListeners();
      },
      onError: (Object e) {
        lastError = '$e';
        notifyListeners();
      },
    ));
  }

  // =================================================================
  // TEACHER STREAMS
  // =================================================================
  void _startTeacher() {
    final today = dayKey(DateTime.now());

    // Students
    _listen(
      _db.collection('students').where('classId', isEqualTo: classId),
          (snap) {
        students = [
          for (final d in snap.docs) ChildInfo.fromMap(d.id, d.data()),
        ]..sort((a, b) => a.rollNo.compareTo(b.rollNo));
      },
    );

    // Attendance (या आठवड्याचा) — आजचा + weekly chart दोन्ही यातून
    _listen(
      _db
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('week', isEqualTo: weekKey(DateTime.now())),
          (snap) {
        _weekRows = [
          for (final d in snap.docs)
            _AttRow(
              (d['studentId'] ?? '') as String,
              (d['day'] ?? '') as String,
              (d['status'] ?? '') as String,
              (d['reason'] ?? '') as String,
            ),
        ];
        final todayRows = _weekRows.where((r) => r.day == today).toList();
        attendanceSaved = todayRows.isNotEmpty;
        attendanceStatuses = {for (final r in todayRows) r.studentId: r.status};
        attendanceReasons = {
          for (final r in todayRows)
            if (r.reason.isNotEmpty) r.studentId: r.reason,
        };
        presentCount =
            todayRows.where((r) => r.status == 'P' || r.status == 'L').length;
        absentCount = todayRows.where((r) => r.status == 'A').length;
      },
    );

    _startClassFeeds();

    // Leave अर्ज (class चे सर्व)
    _listen(
      _classCol('leaves').orderBy('createdAt', descending: true).limit(100),
          (snap) => leaves = _leavesFrom(snap.docs),
    );

    // Photos (teacher ला सर्व)
    _listen(
      _classCol('photos').orderBy('sentAt', descending: true).limit(40),
          (snap) => _buildPhotoBatches(snap.docs),
    );

    // Message threads (list + unread)
    _listen(
      _db.collection('threads').where('classId', isEqualTo: classId),
          (snap) {
        _threadMetas
          ..clear()
          ..addEntries(snap.docs.map((d) {
            final x = d.data();
            return MapEntry(
              d.id,
              ThreadMeta(
                studentId: d.id,
                studentName: (x['studentName'] ?? '') as String,
                parentName: (x['parentName'] ?? '') as String,
                lastText: (x['lastText'] ?? '') as String,
                lastAt: _dt(x['lastAt']),
                teacherUnread: (x['teacherUnread'] ?? 0) as int,
              ),
            );
          }));
      },
    );
  }

  // =================================================================
  // PARENT STREAMS
  // =================================================================
  Future<void> _startParent(String studentId) async {
    final sdoc = await _db.collection('students').doc(studentId).get();
    if (!sdoc.exists) throw 'Student record not found.';
    child = ChildInfo.fromMap(sdoc.id, sdoc.data()!);
    classId = child.classId;
    className = child.className;

    final cdoc = await _db.collection('classes').doc(classId).get();
    if (cdoc.exists) {
      final c = cdoc.data()!;
      teacherName = (c['teacherName'] ?? 'Teacher') as String;
      className = (c['className'] ?? child.className) as String;
      schoolName = (c['schoolName'] ?? '') as String;
    }

    // Class चा teacher / नाव बदलला (Admin ने नवीन teacher assign केला) तर लगेच दिसेल.
    if (classId.isNotEmpty) _subs.add(_db.collection('classes').doc(classId).snapshots().listen(
          (d) {
        if (!d.exists) return;
        final c = d.data()!;
        final tn = (c['teacherName'] ?? '') as String;
        teacherName = tn.isEmpty ? 'Teacher' : tn;
        className = (c['className'] ?? className) as String;
        schoolName = (c['schoolName'] ?? schoolName) as String;
        notifyListeners();
      },
      onError: (Object e) {
        lastError = '$e';
      },
    ));

    // Child profile live (teacher ने बदल केला तर दिसेल)
    _subs.add(_db.collection('students').doc(studentId).snapshots().listen(
          (d) {
        if (d.exists) {
          child = ChildInfo.fromMap(d.id, d.data()!);
          notifyListeners();
        }
      },
      // बदल: access मध्येच बंद झाला तर app crash/unhandled error होऊ नये.
      onError: (Object e) {
        lastError = '$e';
        notifyListeners();
      },
    ));

    // आजचा attendance (फक्त या मुलाचा)
    _listen(
      _db
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('day', isEqualTo: dayKey(DateTime.now())),
          (snap) {
        attendanceSaved = snap.docs.isNotEmpty;
        attendanceStatuses = {
          for (final d in snap.docs) studentId: (d['status'] ?? '') as String,
        };
        attendanceReasons = {
          for (final d in snap.docs)
            if (((d['reason'] ?? '') as String).isNotEmpty)
              studentId: d['reason'] as String,
        };
      },
    );

    // पूर्ण हजेरी history (Parent च्या Attendance screen साठी)
    _listen(
      _db.collection('attendance').where('studentId', isEqualTo: studentId),
          (snap) {
        final list = <AttendanceDay>[];
        for (final d in snap.docs) {
          final x = d.data();
          final date = DateTime.tryParse((x['day'] ?? '') as String);
          if (date == null) continue;
          list.add(AttendanceDay(
            date,
            (x['status'] ?? '') as String,
            (x['reason'] ?? '') as String,
          ));
        }
        list.sort((a, b) => b.date.compareTo(a.date));
        attendanceHistory = list;
      },
    );

    _startClassFeeds();

    // Leave अर्ज: फक्त या मुलाचे (नवीन आधी — sort इथेच, म्हणून index लागत नाही)
    _listen(
      _classCol('leaves').where('studentId', isEqualTo: studentId),
          (snap) => leaves = _leavesFrom(snap.docs),
    );

    // Photos: फक्त या मुलाचे + whole class
    _listen(
      _classCol('photos')
          .where('audience', arrayContainsAny: [studentId, 'all']),
          (snap) => _buildPhotoBatches(snap.docs),
    );

    // Fees + receipts
    _listen(
      _db.collection('students').doc(studentId).collection('fees'),
          (snap) {
        fees = [
          for (final d in snap.docs)
            FeeItem(
              (d['title'] ?? '') as String,
              (d['amount'] ?? 0) as int,
              _feeStatus((d['status'] ?? 'upcoming') as String),
              _dt(d['dueDate']),
              id: d.id,
            ),
        ];
        fees.sort((a, b) => _feeOrder(snap.docs, a).compareTo(
          _feeOrder(snap.docs, b),
        ));
      },
    );
    _listen(
      _db
          .collection('students')
          .doc(studentId)
          .collection('receipts')
          .orderBy('date', descending: true),
          (snap) {
        receipts = [
          for (final d in snap.docs)
            FeeReceipt(
              (d['title'] ?? '') as String,
              (d['amount'] ?? 0) as int,
              _dt(d['date']) ?? DateTime.now(),
              (d['mode'] ?? '') as String,
              id: d.id,
              feeId: (d.data()['feeId'] ?? '') as String,
            ),
        ];
      },
    );

    // Thread meta (unread) + messages
    _subs.add(_db.collection('threads').doc(studentId).snapshots().listen((d) {
      final x = d.data();
      _myThreadMeta =
      x == null ? null : _ParentThreadMeta((x['parentUnread'] ?? 0) as int);
      notifyListeners();
    }, onError: (Object e) {
      lastError = '$e';
      notifyListeners();
    }));
    _ensureThread(studentId);
  }

  int _feeOrder(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      FeeItem item) {
    for (final d in docs) {
      if (d.id == item.id) return (d.data()['order'] ?? 0) as int;
    }
    return 0;
  }

  FeeStatus _feeStatus(String s) {
    switch (s) {
      case 'paid':
        return FeeStatus.paid;
      case 'due':
        return FeeStatus.due;
      default:
        return FeeStatus.upcoming;
    }
  }

  // =================================================================
  // CLASS-WIDE FEEDS (Teacher + Parent दोघे वाचतात)
  // =================================================================
  void _startClassFeeds() {
    // Diary
    _listen(
      _classCol('diary').orderBy('date', descending: true).limit(60),
          (snap) {
        diaryPosts = [
          for (final d in snap.docs)
            DiaryPost(
              date: _dt(d['date']) ?? DateTime.now(),
              items: [
                for (final i in (d['items'] ?? const []) as List)
                  DiaryLine(
                    ((i as Map)['label'] ?? '') as String,
                    (i['text'] ?? '') as String,
                  ),
              ],
              mood: d['mood'] as String?,
              homeNote: (d['homeNote'] ?? '') as String,
              bring: List<String>.from(d['bring'] ?? const []),
              publishedAt: _dt(d['publishedAt']) ?? DateTime.now(),
            ),
        ];
      },
    );

    // Circulars
    _listen(
      _classCol('circulars').orderBy('sentAt', descending: true).limit(100),
          (snap) {
        circulars = [for (final d in snap.docs) CircularRecord.fromDoc(d)];
      },
    );

    // Extra events
    _listen(
      _classCol('events').orderBy('date'),
          (snap) {
        _extraEvents = [
          for (final d in snap.docs)
            SchoolEvent(
              id: d.id,
              date: _dt(d['date']) ?? DateTime.now(),
              title: (d['title'] ?? '') as String,
              category: (d['category'] ?? 'Event') as String,
              note: (d['note'] ?? '') as String,
            ),
        ];
      },
    );
  }

  void _buildPhotoBatches(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // प्रत्येक photo वेगळा document आहे; batchId नुसार परत गट करतो.
    final map = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final d in docs) {
      map.putIfAbsent((d['batchId'] ?? d.id) as String, () => []).add(d);
    }
    final out = <PhotoBatch>[];
    for (final entry in map.entries) {
      final group = entry.value;
      final first = group.first.data();
      out.add(PhotoBatch(
        batchId: entry.key,
        photos: [
          for (final d in group)
            SharedPhoto(
              (d['colorIndex'] ?? 0) as int,
              List<String>.from(d['tags'] ?? const []),
              url: d['url'] as String?,
            ),
        ],
        caption: (first['caption'] ?? '') as String,
        wholeClass: (first['wholeClass'] ?? false) as bool,
        sentAt: _dt(first['sentAt']) ?? DateTime.now(),
      ));
    }
    out.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    photoBatches = out;
  }

  // =================================================================
  // TEACHER ACTIONS
  // =================================================================

  /// Teacher: नवीन विद्यार्थी जोडतो. `parentEmail` वरून parent app मध्ये link होतं.
  Future<void> addStudent(ChildInfo s) async {
    await _db.collection('students').add(
      ChildInfo(
        name: s.name,
        className: className,
        rollNo: s.rollNo,
        dob: s.dob,
        bloodGroup: s.bloodGroup,
        gender: s.gender,
        allergyNote: s.allergyNote,
        parentName: s.parentName,
        parentEmail: s.parentEmail,
        classId: classId,
        pickupNote: s.pickupNote,
        contacts: s.contacts,
      ).toMap(),
    );
  }

  /// Teacher: विद्यार्थ्याची माहिती बदलतो.
  /// `previous` दिला आणि parent email बदलला असेल तर जुन्या parent चं login
  /// profile काढतो (नवीन email ने parent पुन्हा login केल्यावर आपोआप link होतो).
  Future<void> updateStudent(ChildInfo s, {ChildInfo? previous}) async {
    // classId नेहमी teacher चा स्वतःचा class ठेवतो (rules: class बदलता येत नाही).
    await _db
        .collection('students')
        .doc(s.id)
        .update({...s.toMap(), 'classId': classId});

    if (previous == null) return;
    final oldMail = previous.parentEmail.trim().toLowerCase();
    final newMail = s.parentEmail.trim().toLowerCase();
    if (oldMail == newMail) return;

    final refs = await _parentProfileRefs(s.id);
    for (final r in refs) {
      await r.delete();
    }
  }

  /// या विद्यार्थ्याशी जोडलेले parent login profiles (`users` docs).
  /// Rules नुसार Teacher फक्त आपल्या class चे `role == parent` profiles वाचू/काढू शकतो.
  Future<List<DocumentReference<Map<String, dynamic>>>> _parentProfileRefs(
      String studentId) async {
    try {
      final q = await _db
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .where('classId', isEqualTo: classId)
          .where('studentId', isEqualTo: studentId)
          .get();
      return q.docs.map((d) => d.reference).toList();
    } catch (e) {
      // Rules अजून deploy झाले नसतील तरी विद्यार्थी delete / edit अडू नये.
      lastError = '$e';
      return const [];
    }
  }

  /// विद्यार्थी + त्याचा संबंधित data (fees, receipts, attendance, chat) एकत्र काढतो.
  /// Student document शेवटी काढतो (rules त्याच्या class वरून बाकीची परवानगी तपासतात).
  Future<void> deleteStudent(String studentId) async {
    final sRef = _db.collection('students').doc(studentId);
    final refs = <DocumentReference<Map<String, dynamic>>>[];

    for (final sub in const ['fees', 'receipts']) {
      final q = await sRef.collection(sub).get();
      refs.addAll(q.docs.map((d) => d.reference));
    }
    final att = await _db
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .where('studentId', isEqualTo: studentId)
        .get();
    refs.addAll(att.docs.map((d) => d.reference));

    // बदल: या मुलाच्या parent चं login profile सुद्धा काढतो, म्हणजे त्या parent ला
    // पुढच्या login ला "Could not load data" error येत नाही.
    refs.addAll(await _parentProfileRefs(studentId));

    final tRef = _db.collection('threads').doc(studentId);
    final msgs = await tRef.collection('messages').get();
    refs.addAll(msgs.docs.map((d) => d.reference));
    // thread document आहे का हे memory मधून बघतो (नसलेल्या doc ला get केलं तर rules error देतात).
    if (_threadMetas.containsKey(studentId)) refs.add(tRef);

    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(400)) {
        batch.delete(r);
      }
      await batch.commit();
    }
    await sRef.delete();
  }

  /// `statuses` चे keys = studentId, values = 'P' / 'A' / 'L'.
  Future<void> saveAttendance({
    required int present,
    required int absent,
    Map<String, String?>? statuses,
    Map<String, String>? reasons,
  }) async {
    final now = DateTime.now();
    final day = dayKey(now);
    final week = weekKey(now);

    if (statuses != null) {
      final batch = _db.batch();
      statuses.forEach((studentId, status) {
        if (status == null || status.isEmpty) return;
        batch.set(_db.collection('attendance').doc('${day}_$studentId'), {
          'classId': classId,
          'studentId': studentId,
          'day': day,
          'week': week,
          'status': status,
          'reason': reasons?[studentId] ?? '',
          'savedBy': uid,
          'savedAt': Timestamp.fromDate(now),
        });
      });
      await batch.commit();
    }
  }

  /// Teacher ने photos पाठवले. प्रत्येक photo स्वतंत्र document (privacy साठी).
  Future<void> addPhotos(
      int count, {
        List<SharedPhoto>? photos,
        String caption = '',
        bool wholeClass = false,
      }) async {
    final list = (photos != null && photos.isNotEmpty)
        ? photos
        : List.generate(count, (i) => SharedPhoto(i % 4, const []));
    final now = DateTime.now();
    final batchId = _db.collection('classes').doc().id;

    // बदल (Spark plan): Firebase Storage ऐवजी लहान केलेला फोटो base64 म्हणून
    // Firestore document मध्येच ठेवतो ('data:image/jpeg;base64,...').
    // Firestore document ची मर्यादा 1 MB आहे, म्हणून मोठा फोटो नाकारतो.
    final urls = <String?>[];
    for (final p in list) {
      if (p.bytes == null) {
        urls.add(p.url);
        continue;
      }
      if (p.bytes!.length > 700 * 1024) {
        throw 'Photo is too large. Please choose a smaller photo.';
      }
      urls.add('data:image/jpeg;base64,${base64Encode(p.bytes!)}');
    }

    final batch = _db.batch();

    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final audience = <String>{};
      if (wholeClass) {
        audience.add('all');
      } else {
        for (final s in students) {
          if (s.matches(p.tags)) audience.add(s.id);
        }
      }
      batch.set(_classCol('photos').doc(), {
        'batchId': batchId,
        'colorIndex': p.colorIndex,
        'tags': p.tags,
        'url': urls[i],
        'caption': caption,
        'wholeClass': wholeClass,
        'audience': audience.toList(),
        'sentAt': Timestamp.fromDate(now),
        'classId': classId,
      });
    }
    await batch.commit();
  }

  Future<String> _uploadBytes(
      String path, Uint8List data, String contentType) async {
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(data, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// Circular चं attachment (PDF / image) Storage वर चढवून download link देतो.
  Future<String> uploadCircularAttachment(
      Uint8List data, String fileName) async {
    final lower = fileName.toLowerCase();
    final type = lower.endsWith('.pdf')
        ? 'application/pdf'
        : lower.endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return _uploadBytes(
      'classes/$classId/circulars/${DateTime.now().millisecondsSinceEpoch}_$safe',
      data,
      type,
    );
  }

  Future<void> publishDiary({
    List<DiaryLine>? items,
    String? mood,
    String? homeNote,
    List<String>? bring,
  }) async {
    final now = DateTime.now();
    await _classCol('diary').doc(dayKey(now)).set({
      'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      'items': [
        for (final i in items ?? const <DiaryLine>[])
          {'label': i.label, 'text': i.text},
      ],
      'mood': mood,
      'homeNote': homeNote ?? '',
      'bring': bring ?? const <String>[],
      'publishedAt': Timestamp.fromDate(now),
      'publishedBy': uid,
    });
  }

  Future<void> addCircular(CircularRecord record) async {
    await _classCol('circulars').add({
      ...record.toMap(),
      'classId': classId,
      'createdBy': uid,
    });
  }

  /// Teacher: पाठवलेलं circular edit करतो (title, message, category, flags, date).
  /// readBy / ackedBy / attachment तसेच राहतात; Parent च्या list मध्ये लगेच बदल दिसतो.
  Future<void> updateCircular(
      String circularId, {
        required String title,
        required String message,
        required String category,
        required bool important,
        required bool needsAck,
        DateTime? eventDate,
      }) async {
    if (circularId.isEmpty) return;
    await _classCol('circulars').doc(circularId).update({
      'title': title.trim(),
      'message': message.trim(),
      'category': category,
      'important': important,
      'needsAck': needsAck,
      'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate),
      'editedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Teacher: चुकीचं circular delete करतो (Parent च्या list मधूनही जातं).
  Future<void> deleteCircular(String circularId) async {
    if (circularId.isEmpty) return;
    await _classCol('circulars').doc(circularId).delete();
  }

  /// Teacher: त्या दिवसाची Diary delete करतो (diary doc id = तारीख).
  Future<void> deleteDiary(DateTime day) async {
    await _classCol('diary').doc(dayKey(day)).delete();
  }

  /// Teacher: एका वेळी पाठवलेले सर्व photos (एक batch) delete करतो.
  Future<void> deletePhotoBatch(String batchId) async {
    if (batchId.isEmpty) return;
    final snap =
    await _classCol('photos').where('batchId', isEqualTo: batchId).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    // जुने photos ज्यांना batchId नाही — तेव्हा batchId = document id.
    if (snap.docs.isEmpty) {
      batch.delete(_classCol('photos').doc(batchId));
    }
    await batch.commit();
  }

  Future<void> addEvent(SchoolEvent e) async {
    await _classCol('events').add({
      'date': Timestamp.fromDate(e.date),
      'title': e.title,
      'category': e.category,
      'note': e.note,
    });
  }

  // =================================================================
  // LEAVE (Parent अर्ज करतो → Teacher approve / decline)
  // =================================================================
  List<LeaveRequest> _leavesFrom(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final list = [
      for (final d in docs)
        LeaveRequest(
          id: d.id,
          studentId: (d['studentId'] ?? '') as String,
          studentName: (d['studentName'] ?? '') as String,
          parentName: (d['parentName'] ?? '') as String,
          fromDate: _dt(d['fromDate']) ?? DateTime.now(),
          toDate: _dt(d['toDate']) ?? DateTime.now(),
          reason: (d['reason'] ?? '') as String,
          status: (d['status'] ?? 'pending') as String,
          teacherNote: (d['teacherNote'] ?? '') as String,
          createdAt: _dt(d['createdAt']) ?? DateTime.now(),
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Teacher: या मुलाची आजच्या दिवसाची मंजूर (approved) रजा, नसेल तर null.
  LeaveRequest? approvedLeaveToday(String studentId) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    for (final l in leaves) {
      if (l.studentId != studentId || !l.isApproved) continue;
      final from = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
      final to = DateTime(l.toDate.year, l.toDate.month, l.toDate.day);
      if (!today.isBefore(from) && !today.isAfter(to)) return l;
    }
    return null;
  }

  /// Teacher: निर्णय बाकी असलेले अर्ज.
  int get pendingLeaveCount => leaves.where((l) => l.isPending).length;

  /// Parent: रजेचा अर्ज पाठवतो.
  Future<void> submitLeave({
    required DateTime from,
    required DateTime to,
    required String reason,
  }) async {
    if (!isParent || child.id.isEmpty) return;
    final now = DateTime.now();
    await _classCol('leaves').add({
      'classId': classId,
      'studentId': child.id,
      'studentName': child.name,
      'parentName': child.parentName,
      'fromDate': Timestamp.fromDate(DateTime(from.year, from.month, from.day)),
      'toDate': Timestamp.fromDate(DateTime(to.year, to.month, to.day)),
      'reason': reason.trim(),
      'status': 'pending',
      'teacherNote': '',
      'createdAt': Timestamp.fromDate(now),
    });
  }

  /// Parent: निर्णय होण्यापूर्वी अर्ज मागे घेतो.
  Future<void> cancelLeave(String leaveId) async {
    if (leaveId.isEmpty) return;
    await _classCol('leaves').doc(leaveId).delete();
  }

  /// Teacher: अर्ज approve / decline करतो (optional note सहित).
  Future<void> decideLeave(String leaveId,
      {required bool approved, String note = ''}) async {
    if (leaveId.isEmpty) return;
    await _classCol('leaves').doc(leaveId).update({
      'status': approved ? 'approved' : 'declined',
      'teacherNote': note.trim(),
      'decidedAt': Timestamp.fromDate(DateTime.now()),
      'decidedBy': uid,
    });
  }

  /// Teacher ने स्वतः जोडलेले events (edit / delete साठी). Circular चे events यात नाहीत.
  List<SchoolEvent> get classEvents {
    final list = [..._extraEvents]..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<void> updateEvent(SchoolEvent e) async {
    if (e.id.isEmpty) return;
    await _classCol('events').doc(e.id).update({
      'date': Timestamp.fromDate(e.date),
      'title': e.title,
      'category': e.category,
      'note': e.note,
    });
  }

  Future<void> deleteEvent(String eventId) async {
    if (eventId.isEmpty) return;
    await _classCol('events').doc(eventId).delete();
  }

  // =================================================================
  // FEES (Teacher)
  // =================================================================
  FeeItem _feeFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return FeeItem(
      (x['title'] ?? '') as String,
      ((x['amount'] ?? 0) as num).toInt(),
      _feeStatus((x['status'] ?? 'upcoming') as String),
      _dt(x['dueDate']),
      id: d.id,
    );
  }

  /// एका मुलाच्या सर्व fees (जुन्या `order` नुसार).
  Future<List<FeeItem>> loadStudentFees(String studentId) async {
    final snap = await _db
        .collection('students')
        .doc(studentId)
        .collection('fees')
        .get();
    final docs = snap.docs.toList()
      ..sort((a, b) => ((a.data()['order'] ?? 0) as num)
          .compareTo((b.data()['order'] ?? 0) as num));
    return [for (final d in docs) _feeFromDoc(d)];
  }

  /// एका मुलाच्या receipts (नवीन आधी).
  Future<List<FeeReceipt>> loadStudentReceipts(String studentId) async {
    final snap = await _db
        .collection('students')
        .doc(studentId)
        .collection('receipts')
        .orderBy('date', descending: true)
        .get();
    return [
      for (final d in snap.docs)
        FeeReceipt(
          (d['title'] ?? '') as String,
          ((d['amount'] ?? 0) as num).toInt(),
          _dt(d['date']) ?? DateTime.now(),
          (d['mode'] ?? '') as String,
          id: d.id,
          feeId: (d.data()['feeId'] ?? '') as String,
        ),
    ];
  }

  /// Class च्या सर्व मुलांच्या fees: studentId -> fees.
  Future<Map<String, List<FeeItem>>> loadClassFees() async {
    final ids = [for (final s in students) s.id];
    final lists = await Future.wait([for (final id in ids) loadStudentFees(id)]);
    return {for (var i = 0; i < ids.length; i++) ids[i]: lists[i]};
  }

  /// एकच fee अनेक मुलांना (whole class) जोडतो.
  Future<void> addFeeForStudents(
      List<String> studentIds,
      String title,
      int amount,
      DateTime? dueDate, {
        bool upcoming = false,
      }) async {
    final order = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Firestore batch मर्यादा 500 — म्हणून 400 च्या तुकड्यात.
    for (var i = 0; i < studentIds.length; i += 400) {
      final chunk = studentIds.skip(i).take(400);
      final batch = _db.batch();
      for (final id in chunk) {
        batch.set(_db.collection('students').doc(id).collection('fees').doc(), {
          'title': title,
          'amount': amount,
          'status': upcoming ? 'upcoming' : 'due',
          'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
          'order': order,
        });
      }
      await batch.commit();
    }
  }

  /// Fee बदलतो. आधीच 'paid' असलेल्या fee ची status बदलत नाही.
  Future<void> updateFee(
      String studentId,
      String feeId, {
        required String title,
        required int amount,
        DateTime? dueDate,
        bool upcoming = false,
      }) async {
    final ref = _db
        .collection('students')
        .doc(studentId)
        .collection('fees')
        .doc(feeId);
    final snap = await ref.get();
    final wasPaid = snap.data()?['status'] == 'paid';
    await ref.update({
      'title': title,
      'amount': amount,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      if (!wasPaid) 'status': upcoming ? 'upcoming' : 'due',
    });
  }

  /// Fee delete; तिच्याशी जोडलेल्या receipts सुद्धा काढतो.
  Future<void> deleteFee(String studentId, String feeId) async {
    final sRef = _db.collection('students').doc(studentId);
    final rec =
    await sRef.collection('receipts').where('feeId', isEqualTo: feeId).get();
    final batch = _db.batch();
    for (final d in rec.docs) {
      batch.delete(d.reference);
    }
    batch.delete(sRef.collection('fees').doc(feeId));
    await batch.commit();
  }

  Future<void> addFee(
      String studentId,
      String title,
      int amount,
      DateTime? dueDate, {
        int order = 0,
        bool upcoming = false,
      }) async {
    await _db.collection('students').doc(studentId).collection('fees').add({
      'title': title,
      'amount': amount,
      'status': upcoming ? 'upcoming' : 'due',
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'order': order,
    });
  }

  /// Fee भरली गेली: status = paid + receipt तयार.
  Future<void> markFeePaid(
      String studentId, FeeItem fee, String mode) async {
    final ref = _db.collection('students').doc(studentId);
    final batch = _db.batch();
    batch.update(ref.collection('fees').doc(fee.id), {'status': 'paid'});
    batch.set(ref.collection('receipts').doc(), {
      'title': fee.title,
      'amount': fee.amount,
      'date': Timestamp.fromDate(DateTime.now()),
      'mode': mode,
      'feeId': fee.id,
    });
    await batch.commit();
  }

  /// नवीन: चुकून "paid" केलेली fee परत "due" करतो (receipt सुद्धा काढतो).
  Future<void> markFeeUnpaid(String studentId, FeeItem fee) async {
    final ref = _db.collection('students').doc(studentId);
    final rec =
    await ref.collection('receipts').where('feeId', isEqualTo: fee.id).get();
    final batch = _db.batch();
    for (final d in rec.docs) {
      batch.delete(d.reference);
    }
    batch.update(ref.collection('fees').doc(fee.id), {'status': 'due'});
    await batch.commit();
  }

  // =================================================================
  // CHAT  (Teacher ↔ Parent एकच thread; thread key = studentId)
  // =================================================================
  String _threadKey(String key) => isParent ? child.id : key;

  void _ensureThread(String key) {
    if (key.isEmpty || _threadSubs.containsKey(key)) return;
    _threadSubs[key] = _db
        .collection('threads')
        .doc(key)
        .collection('messages')
        .orderBy('at')
        .snapshots()
        .listen((snap) {
      _threads[key] = [
        for (final d in snap.docs)
          ChatMessage(
            (d.data()['text'] ?? '') as String,
            (d.data()['fromTeacher'] ?? false) as bool,
            timeLabel(_dt(d.data()['at']) ?? DateTime.now()),
            id: d.id,
            at: _dt(d.data()['at']),
            image: (d.data()['image'] ?? '') as String,
          ),
      ];
      notifyListeners();
    }, onError: (Object e) {
      lastError = '$e';
      notifyListeners();
    });
  }

  /// Teacher साठी key = studentId. Parent साठी key आपोआप स्वतःचा child.id होतो.
  List<ChatMessage> thread(String key) {
    final k = _threadKey(key);
    _ensureThread(k);
    return _threads[k] ?? const <ChatMessage>[];
  }

  ThreadMeta? metaFor(String studentId) => _threadMetas[studentId];

  /// Teacher: सर्व conversations, शेवटचा संदेश असलेले आधी (Home + Messages साठी).
  List<ThreadMeta> get threadList {
    final list = _threadMetas.values
        .where((m) => m.lastText.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final ta = a.lastAt;
        final tb = b.lastAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
    return list;
  }

  /// फोटो message साठी साठवला जाणारा default मजकूर (caption नसेल तेव्हा).
  static const String photoMessageText = '📷 Photo';

  /// फोटो (base64) साठी कमाल आकार – Firestore document मर्यादा 1 MB आहे.
  static const int maxChatPhotoBytes = 700 * 1024;

  Future<void> sendMessage(String key, String text,
      {required bool fromTeacher, Uint8List? imageBytes}) async {
    final k = _threadKey(key);
    final hasPhoto = imageBytes != null && imageBytes.isNotEmpty;
    if (k.isEmpty || (text.trim().isEmpty && !hasPhoto)) return;
    if (hasPhoto && imageBytes!.length > maxChatPhotoBytes) {
      throw 'Photo is too large. Please choose a smaller photo.';
    }
    final body = text.trim().isEmpty ? photoMessageText : text.trim();
    // बदल: कोण पाठवतो हे login role वरून ठरतं (rules मध्ये fromTeacher खोटं
    // लिहिता येत नाही). `fromTeacher` parameter जुन्या screens साठी तसाच ठेवला आहे.
    final sentByTeacher = !isParent;
    final now = DateTime.now();
    final student = isParent
        ? child
        : students.firstWhere((s) => s.id == k, orElse: ChildInfo.empty);

    final tRef = _db.collection('threads').doc(k);
    final batch = _db.batch();
    batch.set(tRef.collection('messages').doc(), {
      'text': body,
      'fromTeacher': sentByTeacher,
      'at': Timestamp.fromDate(now),
      if (hasPhoto) 'image': 'data:image/jpeg;base64,${base64Encode(imageBytes!)}',
    });
    batch.set(
      tRef,
      {
        'classId': classId,
        'studentName': student.name,
        'parentName': student.parentName,
        'lastText': body,
        'lastAt': Timestamp.fromDate(now),
        if (sentByTeacher)
          'parentUnread': FieldValue.increment(1)
        else
          'teacherUnread': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// उघडलेल्या thread चा unread counter 0 करतो (आपल्या बाजूचा).
  /// आधीच 0 असेल तर काही लिहीत नाही; classId सोबत लिहितो म्हणजे Firestore
  /// rules पास होतात (thread document अजून नसला तरी).
  Future<void> markThreadRead(String key) async {
    final k = _threadKey(key);
    if (k.isEmpty) return;
    final unread = isParent
        ? (_myThreadMeta?.parentUnreadCount ?? 0)
        : (_threadMetas[k]?.teacherUnread ?? 0);
    if (unread == 0) return;
    try {
      await _db.collection('threads').doc(k).set(
        {
          'classId': classId,
          isParent ? 'parentUnread' : 'teacherUnread': 0,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      lastError = '$e';
    }
  }

  // =================================================================
  // PARENT READ HELPERS
  // =================================================================
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool sameDay(DateTime a, DateTime b) => _sameDay(a, b);

  /// 'P' / 'L' / 'A' किंवा '' (अजून mark नाही)
  String get childAttendanceCode => attendanceStatuses[child.id] ?? '';

  /// Parent: त्या दिवशीचे सर्व photos. Firestore query आधीच फक्त या मुलाचे +
  /// whole-class photos आणते, म्हणून नावाने पुन्हा गाळत नाही
  /// (नाहीतर whole-class photos Home च्या count मध्ये येत नव्हते).
  List<SharedPhoto> childPhotosOn(DateTime day) {
    final out = <SharedPhoto>[];
    for (final b in photoBatches) {
      if (_sameDay(b.sentAt, day)) out.addAll(b.photos);
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
    final all = circulars
        .where((c) => c.scheduledFor == null || !c.scheduledFor!.isAfter(now))
        .toList();
    all.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return all;
  }

  /// Parent ने वाचलेले circulars.
  Set<CircularRecord> get readCirculars => {
    for (final c in circulars)
      if (c.readBy.contains(child.id) || _pendingRead.contains(c.id)) c,
  };

  bool isNewCircular(CircularRecord c) =>
      !readCirculars.contains(c) &&
          DateTime.now().difference(c.sentAt).inDays < 3;

  int get unreadCircularCount => visibleCirculars.where(isNewCircular).length;

  Future<void> markCircularRead(CircularRecord c) async {
    if (!isParent || c.id.isEmpty) return;
    if (c.readBy.contains(child.id) || !_pendingRead.add(c.id)) return;
    notifyListeners();
    try {
      await _classCol('circulars').doc(c.id).update({
        'readBy': FieldValue.arrayUnion([child.id]),
      });
    } catch (e) {
      // Save झालं नाही तर 'read' खूण परत काढतो.
      _pendingRead.remove(c.id);
      lastError = '$e';
      notifyListeners();
    }
  }

  bool isAcked(CircularRecord c) =>
      c.ackedBy.contains(child.id) || _pendingAck.contains(c.id);

  /// Parent ने "I have read this" दाबलं. Circular आपोआप "read" सुद्धा होतं.
  Future<void> acknowledgeCircular(CircularRecord c) async {
    if (!isParent || c.id.isEmpty) return;
    _pendingRead.add(c.id);
    _pendingAck.add(c.id);
    notifyListeners();
    try {
      await _classCol('circulars').doc(c.id).update({
        'readBy': FieldValue.arrayUnion([child.id]),
        'ackedBy': FieldValue.arrayUnion([child.id]),
      });
    } catch (e) {
      _pendingRead.remove(c.id);
      _pendingAck.remove(c.id);
      lastError = '$e';
      notifyListeners();
      rethrow; // screen ला कळावं म्हणून
    }
  }

  /// Parent: acknowledgement बाकी असलेल्या circulars ची संख्या.
  int get pendingAckCount =>
      visibleCirculars.where((c) => c.needsAck && !isAcked(c)).length;

  /// Teacher: या circular साठी किती families नी अजून acknowledge केलं नाही.
  int ackPendingFamilies(CircularRecord c) {
    final left = students.length - c.ackedBy.length;
    return left < 0 ? 0 : left;
  }

  FeeItem? get nextDueFee {
    for (final f in fees) {
      if (f.status == FeeStatus.due) return f;
    }
    return null;
  }

  /// Calendar events = extra events + circulars ज्यांना event date आहे.
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

  /// Teacher home च्या weekly chart साठी: weekdayIndex 0=Mon … 4=Fri.
  /// खऱ्या attendance वरून %, डेटा नसेल तर 0.
  int weeklyPercent(int weekdayIndex) {
    final monday = _mondayOf(DateTime.now());
    final d = DateTime(monday.year, monday.month, monday.day + weekdayIndex);
    final key = dayKey(d);
    final rows = _weekRows.where((r) => r.day == key).toList();
    if (rows.isEmpty) return 0;
    final present = rows.where((r) => r.status == 'P' || r.status == 'L');
    return present.length * 100 ~/ rows.length;
  }

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

  /// '2026-11-23'  (Firestore document id / query साठी)
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  /// आठवड्याचा सोमवार (weekly attendance query साठी)
  static String weekKey(DateTime d) => dayKey(_mondayOf(d));

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

class _AttRow {
  const _AttRow(this.studentId, this.day, this.status, this.reason);
  final String studentId;
  final String day;
  final String status;
  final String reason;
}

class _ParentThreadMeta {
  const _ParentThreadMeta(this.parentUnreadCount);
  final int parentUnreadCount;
}