import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';

// =====================================================================
// ADMIN MODELS  (सर्व data Firebase Firestore मधून – dummy data नाही)
// =====================================================================

String _s(dynamic v) => v == null ? '' : v.toString();

DateTime? _date(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

class AdminTeacher {
  const AdminTeacher({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.schoolName,
    required this.employeeId,
    required this.className,
    required this.classId,
    this.approved = true,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String schoolName;
  final String employeeId;
  final String className;
  final String classId;

  /// false = Admin ने अजून approve केलेलं नाही (Teacher app ला data दिसणार नाही).
  /// जुन्या teachers मध्ये field नसतो => approved धरतो (Firestore rules प्रमाणेच).
  final bool approved;
  final DateTime? createdAt;

  factory AdminTeacher.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return AdminTeacher(
      uid: d.id,
      name: _s(x['name']),
      email: _s(x['email']),
      phone: _s(x['phone']),
      schoolName: _s(x['schoolName']),
      employeeId: _s(x['employeeId']),
      className: _s(x['className']),
      classId: _s(x['classId']),
      approved: x['approved'] != false,
      createdAt: _date(x['createdAt']),
    );
  }
}

class AdminClass {
  const AdminClass({
    required this.id,
    required this.className,
    required this.schoolName,
    required this.teacherName,
    required this.teacherUid,
  });

  final String id;
  final String className;
  final String schoolName;
  final String teacherName;
  final String teacherUid;

  factory AdminClass.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return AdminClass(
      id: d.id,
      className: _s(x['className']),
      schoolName: _s(x['schoolName']),
      teacherName: _s(x['teacherName']),
      teacherUid: _s(x['teacherUid']),
    );
  }
}

class AdminParentUser {
  const AdminParentUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.studentId,
    required this.classId,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String studentId;
  final String classId;
  final DateTime? createdAt;

  factory AdminParentUser.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return AdminParentUser(
      uid: d.id,
      name: _s(x['name']),
      email: _s(x['email']),
      studentId: _s(x['studentId']),
      classId: _s(x['classId']),
      createdAt: _date(x['createdAt']),
    );
  }
}

class AttendanceRec {
  const AttendanceRec({
    required this.classId,
    required this.studentId,
    required this.day,
    required this.status,
    required this.reason,
  });

  final String classId;
  final String studentId;
  final String day; // '2026-11-23'
  final String status; // P / A / L
  final String reason;

  bool get isPresent => status == 'P' || status == 'L';
}

class AdminFee {
  const AdminFee({
    required this.id,
    required this.studentId,
    required this.title,
    required this.amount,
    required this.status,
    required this.dueDate,
    required this.order,
  });

  final String id;
  final String studentId;
  final String title;
  final int amount;
  final FeeStatus status;
  final DateTime? dueDate;
  final int order;

  factory AdminFee.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    final st = _s(x['status']);
    return AdminFee(
      id: d.id,
      // path: students/{studentId}/fees/{feeId}
      studentId: d.reference.parent.parent?.id ?? '',
      title: _s(x['title']),
      amount: (x['amount'] is num) ? (x['amount'] as num).toInt() : 0,
      status: st == 'paid'
          ? FeeStatus.paid
          : st == 'due'
          ? FeeStatus.due
          : FeeStatus.upcoming,
      dueDate: _date(x['dueDate']),
      order: (x['order'] is num) ? (x['order'] as num).toInt() : 0,
    );
  }
}

class AdminReceipt {
  const AdminReceipt({
    required this.id,
    required this.studentId,
    required this.title,
    required this.amount,
    required this.mode,
    required this.date,
  });

  final String id;
  final String studentId;
  final String title;
  final int amount;
  final String mode;
  final DateTime date;

  factory AdminReceipt.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return AdminReceipt(
      id: d.id,
      // path: students/{studentId}/receipts/{id}
      studentId: d.reference.parent.parent?.id ?? '',
      title: _s(x['title']),
      amount: (x['amount'] is num) ? (x['amount'] as num).toInt() : 0,
      mode: _s(x['mode']),
      date: _date(x['date']) ?? DateTime.now(),
    );
  }
}

class AdminCircular {
  const AdminCircular({
    required this.id,
    required this.classId,
    required this.title,
    required this.audience,
    required this.category,
    required this.message,
    required this.important,
    required this.needsAck,
    required this.families,
    required this.sentAt,
    required this.readCount,
    required this.ackCount,
    this.readBy = const [],
    this.ackedBy = const [],
    this.eventDate,
  });

  final String id;
  final String classId;
  final String title;
  final String audience;
  final String category;
  final String message;
  final bool important;
  final bool needsAck;
  final int families;
  final DateTime sentAt;
  final DateTime? eventDate;
  final int readCount;
  final int ackCount;

  /// studentId lists (कोणत्या मुलांच्या parents नी वाचलं / acknowledge केलं)
  final List<String> readBy;
  final List<String> ackedBy;

  factory AdminCircular.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return AdminCircular(
      id: d.id,
      // path: classes/{classId}/circulars/{id}
      classId: d.reference.parent.parent?.id ?? _s(x['classId']),
      title: _s(x['title']),
      audience: _s(x['audience']),
      category: x['category'] == null ? 'Notice' : _s(x['category']),
      message: _s(x['message']),
      important: x['important'] == true,
      needsAck: x['needsAck'] == true,
      families: (x['families'] is num) ? (x['families'] as num).toInt() : 0,
      sentAt: _date(x['sentAt']) ?? DateTime.now(),
      eventDate: _date(x['eventDate']),
      readCount: (x['readBy'] is List) ? (x['readBy'] as List).length : 0,
      ackCount: (x['ackedBy'] is List) ? (x['ackedBy'] as List).length : 0,
      readBy: (x['readBy'] is List)
          ? [for (final v in x['readBy'] as List) v.toString()]
          : const [],
      ackedBy: (x['ackedBy'] is List)
          ? [for (final v in x['ackedBy'] as List) v.toString()]
          : const [],
    );
  }
}

class AdminEvent {
  const AdminEvent({
    required this.id,
    required this.classId,
    required this.date,
    required this.title,
    required this.category,
    required this.note,
  });

  final String id;
  final String classId;
  final DateTime date;
  final String title;
  final String category;
  final String note;

  factory AdminEvent.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return AdminEvent(
      id: d.id,
      classId: d.reference.parent.parent?.id ?? '',
      date: _date(x['date']) ?? DateTime.now(),
      title: _s(x['title']),
      category: x['category'] == null ? 'Event' : _s(x['category']),
      note: _s(x['note']),
    );
  }
}

class AdminDiary {
  const AdminDiary({
    required this.id,
    required this.classId,
    required this.date,
    required this.items,
    required this.mood,
    required this.homeNote,
    required this.bring,
    required this.publishedAt,
  });

  final String id;
  final String classId;
  final DateTime date;
  final List<DiaryLine> items;
  final String mood;
  final String homeNote;
  final List<String> bring;
  final DateTime? publishedAt;

  factory AdminDiary.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return AdminDiary(
      id: d.id,
      // path: classes/{classId}/diary/{id}
      classId: d.reference.parent.parent?.id ?? '',
      date: _date(x['date']) ?? _date(x['publishedAt']) ?? DateTime.now(),
      items: (x['items'] is List)
          ? [
        for (final i in x['items'] as List)
          if (i is Map) DiaryLine(_s(i['label']), _s(i['text'])),
      ]
          : const [],
      mood: _s(x['mood']),
      homeNote: _s(x['homeNote']),
      bring: (x['bring'] is List)
          ? [for (final b in x['bring'] as List) b.toString()]
          : const [],
      publishedAt: _date(x['publishedAt']),
    );
  }
}

class AdminPhoto {
  const AdminPhoto({
    required this.id,
    required this.classId,
    required this.batchId,
    required this.url,
    required this.caption,
    required this.wholeClass,
    required this.tags,
    required this.audience,
    required this.sentAt,
  });

  final String id;
  final String classId;
  final String batchId;
  final String url;
  final String caption;
  final bool wholeClass;
  final List<String> tags;
  final List<String> audience;
  final DateTime sentAt;

  factory AdminPhoto.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    List<String> strs(dynamic v) =>
        (v is List) ? [for (final e in v) e.toString()] : const [];
    return AdminPhoto(
      id: d.id,
      // path: classes/{classId}/photos/{id}
      classId: d.reference.parent.parent?.id ?? _s(x['classId']),
      batchId: _s(x['batchId']),
      url: _s(x['url']),
      caption: _s(x['caption']),
      wholeClass: x['wholeClass'] == true,
      tags: strs(x['tags']),
      audience: strs(x['audience']),
      sentAt: _date(x['sentAt']) ?? DateTime.now(),
    );
  }
}

/// Teacher ↔ Parent chat thread (document id = studentId).
class AdminThread {
  const AdminThread({
    required this.studentId,
    required this.classId,
    required this.studentName,
    required this.parentName,
    required this.lastText,
    required this.lastAt,
    required this.teacherUnread,
    required this.parentUnread,
  });

  final String studentId;
  final String classId;
  final String studentName;
  final String parentName;
  final String lastText;
  final DateTime? lastAt;
  final int teacherUnread;
  final int parentUnread;

  factory AdminThread.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    int n(dynamic v) => (v is num) ? v.toInt() : 0;
    return AdminThread(
      studentId: d.id,
      classId: _s(x['classId']),
      studentName: _s(x['studentName']),
      parentName: _s(x['parentName']),
      lastText: _s(x['lastText']),
      lastAt: _date(x['lastAt']),
      teacherUnread: n(x['teacherUnread']),
      parentUnread: n(x['parentUnread']),
    );
  }
}

class AdminMessage {
  const AdminMessage({
    required this.id,
    required this.text,
    required this.fromTeacher,
    required this.at,
  });

  final String id;
  final String text;
  final bool fromTeacher;
  final DateTime? at;

  factory AdminMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return AdminMessage(
      id: d.id,
      text: _s(x['text']),
      fromTeacher: x['fromTeacher'] == true,
      at: _date(x['at']),
    );
  }
}

class AdminLeave {
  const AdminLeave({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.reason,
    required this.status,
    required this.fromDate,
    required this.toDate,
    required this.createdAt,
    this.parentName = '',
    this.teacherNote = '',
    this.decidedAt,
  });

  final String id;
  final String classId;
  final String studentId;
  final String studentName;
  final String parentName;
  final String reason;
  final String status; // pending / approved / declined
  final String teacherNote; // निर्णयासोबत दिलेली note
  final DateTime? fromDate;
  final DateTime? toDate;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  factory AdminLeave.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return AdminLeave(
      id: d.id,
      classId: _s(x['classId']),
      studentId: _s(x['studentId']),
      studentName: _s(x['studentName']),
      parentName: _s(x['parentName']),
      reason: _s(x['reason']),
      status: _s(x['status']).isEmpty ? 'pending' : _s(x['status']),
      teacherNote: _s(x['teacherNote']),
      fromDate: _date(x['fromDate']),
      toDate: _date(x['toDate']),
      createdAt: _date(x['createdAt']),
      decidedAt: _date(x['decidedAt']),
    );
  }
}

// =====================================================================
// ADMIN STATE
// ---------------------------------------------------------------------
// Admin फक्त `users/{uid}` मध्ये role == 'admin' असेल तरच login होतो.
// Teacher / Parent app मध्ये save झालेला सगळा data इथे real-time दिसतो.
// =====================================================================
class AdminState extends ChangeNotifier {
  AdminState._();
  static final AdminState instance = AdminState._();

  /// Attendance चा किती दिवसांचा इतिहास load करायचा.
  static const int attendanceWindowDays = 60;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final List<StreamSubscription<dynamic>> _subs = [];

  // ---------- session ----------
  bool ready = false;
  String uid = '';
  String adminName = 'Admin';
  String adminEmail = '';
  String schoolName = '';
  String? lastError;

  // ---------- data ----------
  List<AdminTeacher> teachers = [];
  List<AdminParentUser> parentUsers = [];
  List<ChildInfo> students = [];
  List<AdminClass> classes = [];
  List<AttendanceRec> attendance = [];
  List<AdminFee> _allFees = [];
  List<AdminReceipt> _allReceipts = [];
  bool _studentsLoaded = false;
  List<AdminCircular> circulars = [];
  List<AdminEvent> events = [];
  List<AdminDiary> diaries = [];
  List<AdminPhoto> photos = [];
  List<AdminThread> threads = [];
  List<AdminLeave> leaves = [];

  /// Fees / receipts फक्त अस्तित्वात असलेल्या students चे (delete केलेल्या मुलांचे
  /// उरलेले जुने records totals मध्ये मोजले जाऊ नयेत म्हणून).
  List<AdminFee> get fees {
    if (!_studentsLoaded) return _allFees;
    final ids = students.map((s) => s.id).toSet();
    return _allFees.where((f) => ids.contains(f.studentId)).toList();
  }

  List<AdminReceipt> get receipts {
    if (!_studentsLoaded) return _allReceipts;
    final ids = students.map((s) => s.id).toSet();
    return _allReceipts.where((r) => ids.contains(r.studentId)).toList();
  }

  /// Screens मध्ये `$e` ऐवजी हा वापरा (वाचता येणारा error text).
  static String errorText(Object e) => _authMessage(e);

  // =================================================================
  // AUTH / SESSION
  // =================================================================
  static String _authMessage(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Wrong email or password.';
        case 'network-request-failed':
          return 'No internet connection.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'user-disabled':
          return 'This account has been disabled.';
      }
      return e.message ?? 'Authentication failed (${e.code}).';
    }
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'Permission denied. Please check the Firestore rules.';
    }
    return e.toString();
  }

  /// Email + password ने Admin login. यशस्वी झाल्यास null, नाहीतर error text.
  Future<String?> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final err = await startSession();
      if (err != null) {
        await logout();
        return err;
      }
      return null;
    } catch (e) {
      return _authMessage(e);
    }
  }

  Future<String?> startSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Please login first.';

    await _cancelAll();
    try {
      final udoc = await _db.collection('users').doc(user.uid).get();
      if (!udoc.exists) {
        return 'No admin profile found for this account.';
      }
      final u = udoc.data()!;
      if (_s(u['role']) != 'admin') {
        return 'This is not an Admin account. '
            'Teachers and parents must use the mobile apps.';
      }

      uid = user.uid;
      adminName = _s(u['name']).isEmpty ? 'Admin' : _s(u['name']);
      adminEmail = user.email ?? _s(u['email']);
      schoolName = _s(u['schoolName']);
      lastError = null;

      _startStreams();
      ready = true;
      notifyListeners();
      return null;
    } catch (e) {
      return _authMessage(e);
    }
  }

  Future<void> logout() async {
    await endSession();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> endSession() async {
    await _cancelAll();
    ready = false;
    uid = '';
    adminName = 'Admin';
    adminEmail = '';
    schoolName = '';
    lastError = null;
    teachers = [];
    parentUsers = [];
    students = [];
    classes = [];
    attendance = [];
    _allFees = [];
    _allReceipts = [];
    _studentsLoaded = false;
    circulars = [];
    events = [];
    diaries = [];
    photos = [];
    threads = [];
    leaves = [];
    notifyListeners();
  }

  Future<void> _cancelAll() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
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
        lastError = _authMessage(e);
        notifyListeners();
      },
    ));
  }

  void _startStreams() {
    _listen(_db.collection('users').where('role', isEqualTo: 'teacher'),
            (snap) {
          teachers = [for (final d in snap.docs) AdminTeacher.fromDoc(d)]
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });

    _listen(_db.collection('users').where('role', isEqualTo: 'parent'),
            (snap) {
          parentUsers = [for (final d in snap.docs) AdminParentUser.fromDoc(d)];
        });

    _listen(_db.collection('students'), (snap) {
      _studentsLoaded = true;
      students = [
        for (final d in snap.docs) ChildInfo.fromMap(d.id, d.data()),
      ]..sort((a, b) {
        final c = a.className.compareTo(b.className);
        return c != 0 ? c : a.rollNo.compareTo(b.rollNo);
      });
    });

    _listen(_db.collection('classes'), (snap) {
      classes = [for (final d in snap.docs) AdminClass.fromDoc(d)]
        ..sort((a, b) => a.className.compareTo(b.className));
    });

    final from = DateTime.now().subtract(
      const Duration(days: attendanceWindowDays),
    );
    _listen(
      _db
          .collection('attendance')
          .where('day', isGreaterThanOrEqualTo: AppState.dayKey(from)),
          (snap) {
        attendance = [
          for (final d in snap.docs)
            AttendanceRec(
              classId: _s(d['classId']),
              studentId: _s(d['studentId']),
              day: _s(d['day']),
              status: _s(d['status']),
              reason: _s(d['reason']),
            ),
        ];
      },
    );

    // Collection-group queries: सर्व classes / students चे subcollections
    _listen(_db.collectionGroup('receipts'), (snap) {
      _allReceipts = [for (final d in snap.docs) AdminReceipt.fromDoc(d)]
        ..sort((a, b) => b.date.compareTo(a.date));
    });

    _listen(_db.collectionGroup('fees'), (snap) {
      _allFees = [for (final d in snap.docs) AdminFee.fromDoc(d)]
        ..sort((a, b) {
          final da = a.dueDate;
          final db = b.dueDate;
          if (da == null && db == null) return a.order.compareTo(b.order);
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
    });

    _listen(_db.collectionGroup('circulars'), (snap) {
      circulars = [for (final d in snap.docs) AdminCircular.fromDoc(d)]
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    });

    _listen(_db.collectionGroup('events'), (snap) {
      events = [for (final d in snap.docs) AdminEvent.fromDoc(d)]
        ..sort((a, b) => a.date.compareTo(b.date));
    });

    _listen(_db.collectionGroup('diary'), (snap) {
      diaries = [for (final d in snap.docs) AdminDiary.fromDoc(d)]
        ..sort((a, b) => b.date.compareTo(a.date));
    });

    _listen(_db.collectionGroup('photos'), (snap) {
      photos = [for (final d in snap.docs) AdminPhoto.fromDoc(d)]
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    });

    _listen(_db.collection('threads'), (snap) {
      threads = [
        for (final d in snap.docs) AdminThread.fromDoc(d),
      ].where((t) => t.lastText.isNotEmpty).toList()
        ..sort((a, b) {
          final ta = a.lastAt;
          final tb = b.lastAt;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
    });

    _listen(_db.collectionGroup('leaves'), (snap) {
      leaves = [for (final d in snap.docs) AdminLeave.fromDoc(d)]
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
    });
  }

  // =================================================================
  // READ HELPERS
  // =================================================================
  String classNameOf(String classId) {
    for (final c in classes) {
      if (c.id == classId) return c.className;
    }
    for (final s in students) {
      if (s.classId == classId && s.className.isNotEmpty) return s.className;
    }
    return classId.isEmpty ? '—' : classId;
  }

  ChildInfo? studentById(String id) {
    for (final s in students) {
      if (s.id == id) return s;
    }
    return null;
  }

  String studentName(String id) => studentById(id)?.name ?? 'Unknown student';

  List<ChildInfo> studentsOfClass(String classId) =>
      students.where((s) => s.classId == classId).toList();

  AdminTeacher? teacherOfClass(String classId) {
    for (final t in teachers) {
      if (t.classId == classId) return t;
    }
    return null;
  }

  bool parentJoined(ChildInfo s) {
    final mail = s.parentEmail.trim().toLowerCase();
    return parentUsers.any((p) =>
    p.studentId == s.id ||
        (mail.isNotEmpty && p.email.trim().toLowerCase() == mail));
  }

  AdminParentUser? parentUserOf(ChildInfo s) {
    final mail = s.parentEmail.trim().toLowerCase();
    for (final p in parentUsers) {
      if (p.studentId == s.id) return p;
    }
    if (mail.isEmpty) return null;
    for (final p in parentUsers) {
      if (p.email.trim().toLowerCase() == mail) return p;
    }
    return null;
  }

  int get parentsJoinedCount => students.where(parentJoined).length;

  // ---------- attendance ----------
  List<AttendanceRec> attendanceOn(String day, {String? classId}) =>
      attendance
          .where((r) =>
      r.day == day && (classId == null || r.classId == classId))
          .toList();

  /// दिलेल्या दिवसाचा attendance % (डेटा नसेल तर null).
  int? attendancePercent(String day, {String? classId}) {
    final rows = attendanceOn(day, classId: classId);
    if (rows.isEmpty) return null;
    final present = rows.where((r) => r.isPresent).length;
    return present * 100 ~/ rows.length;
  }

  String get todayKey => AppState.dayKey(DateTime.now());

  int get todayPresent =>
      attendanceOn(todayKey).where((r) => r.isPresent).length;

  int get todayAbsent =>
      attendanceOn(todayKey).where((r) => r.status == 'A').length;

  // ---------- fees ----------
  int get pendingFeesTotal => fees
      .where((f) => f.status == FeeStatus.due)
      .fold<int>(0, (sum, f) => sum + f.amount);

  int get collectedFeesTotal => fees
      .where((f) => f.status == FeeStatus.paid)
      .fold<int>(0, (sum, f) => sum + f.amount);

  int get receiptsTotal =>
      receipts.fold<int>(0, (sum, r) => sum + r.amount);

  int get studentsWithDues => fees
      .where((f) => f.status == FeeStatus.due)
      .map((f) => f.studentId)
      .toSet()
      .length;

  // =================================================================
  // CLASS ACTIONS
  // =================================================================
  Future<String> addClass(String className, String school) async {
    final id = AuthService.classIdFor(school, className);
    await _db.collection('classes').doc(id).set({
      'className': className.trim(),
      'schoolName': school.trim(),
    }, SetOptions(merge: true));
    return id;
  }

  /// Firestore मध्ये document delete केला तरी त्याचे subcollections राहतात.
  /// म्हणून class च्या diary / photos / circulars / events सुद्धा काढतो.
  Future<void> deleteClass(String classId) async {
    final cRef = _db.collection('classes').doc(classId);
    final refs = <DocumentReference>[];
    for (final sub in const ['diary', 'photos', 'circulars', 'events']) {
      final q = await cRef.collection(sub).get();
      refs.addAll(q.docs.map((d) => d.reference));
    }
    refs.add(cRef);
    await _deleteDocs(refs);
  }

  /// 400-400 च्या batches मध्ये delete (Firestore batch limit 500).
  Future<void> _deleteDocs(List<DocumentReference> refs) async {
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(400)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }

  // =================================================================
  // TEACHER ACTIONS
  // =================================================================
  /// Teacher ला class assign करतो (users + classes दोन्ही update).
  Future<void> assignTeacher(AdminTeacher t, AdminClass c) async {
    final batch = _db.batch();
    // आधीच्या class वर याच teacher चं नाव राहू नये.
    if (t.classId.isNotEmpty && t.classId != c.id) {
      final old = classes.where((x) => x.id == t.classId).toList();
      if (old.isNotEmpty && old.first.teacherUid == t.uid) {
        batch.set(
          _db.collection('classes').doc(old.first.id),
          {'teacherName': '', 'teacherUid': ''},
          SetOptions(merge: true),
        );
      }
    }
    batch.update(_db.collection('users').doc(t.uid), {
      'className': c.className,
      'classId': c.id,
      'schoolName': c.schoolName,
    });
    batch.set(
      _db.collection('classes').doc(c.id),
      {
        'teacherName': t.name,
        'teacherUid': t.uid,
        'className': c.className,
        'schoolName': c.schoolName,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Teacher approve / revoke. Approve होईपर्यंत Teacher app मध्ये data दिसत नाही.
  Future<void> setTeacherApproved(AdminTeacher t, bool approved) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(t.uid), {'approved': approved});
    // Approve करताना त्याच्या class चा document तयार (नसल्यास) – Parent app ला teacher नाव दिसतं.
    if (approved && t.classId.isNotEmpty) {
      batch.set(
        _db.collection('classes').doc(t.classId),
        {
          'teacherName': t.name,
          'teacherUid': t.uid,
          'className': t.className,
          'schoolName': t.schoolName,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Teacher चा profile काढतो (त्याला app मध्ये login करू देत नाही).
  /// टीप: Firebase Auth मधलं account Firebase Console मधून delete करावं लागतं.
  Future<void> removeTeacher(AdminTeacher t) async {
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(t.uid));
    if (t.classId.isNotEmpty) {
      batch.set(
        _db.collection('classes').doc(t.classId),
        {'teacherName': '', 'teacherUid': ''},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Teacher ला class मधून काढतो (login तसंच राहतं).
  Future<void> unassignTeacher(AdminTeacher t) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(t.uid), {
      'className': '',
      'classId': '',
    });
    if (t.classId.isNotEmpty) {
      final cls = classes.where((c) => c.id == t.classId).toList();
      if (cls.isNotEmpty && cls.first.teacherUid == t.uid) {
        batch.set(
          _db.collection('classes').doc(t.classId),
          {'teacherName': '', 'teacherUid': ''},
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  // =================================================================
  // STUDENT ACTIONS
  // =================================================================
  int nextRollFor(String classId) {
    var max = 0;
    for (final s in students) {
      if (s.classId == classId && s.rollNo > max) max = s.rollNo;
    }
    return max + 1;
  }

  /// `previous` = edit करण्यापूर्वीचा student. त्यावरून:
  ///  - parent email बदलला => जुना parent link तोडतो (जुन्या parent ला access जातो)
  ///  - class बदलली => parent चा users.classId + chat thread चा classId update
  ///    (नाहीतर Firestore rules मुळे parent ला नवीन class चा data दिसत नाही).
  Future<void> saveStudent(ChildInfo s,
      {bool isNew = false, ChildInfo? previous}) async {
    if (isNew) {
      await _db.collection('students').add(s.toMap());
      return;
    }
    await _db.collection('students').doc(s.id).update(s.toMap());
    if (previous == null) return;

    final oldMail = previous.parentEmail.trim().toLowerCase();
    final newMail = s.parentEmail.trim().toLowerCase();
    final linked = await _db
        .collection('users')
        .where('studentId', isEqualTo: s.id)
        .get();

    if (oldMail != newMail) {
      await _deleteDocs([for (final d in linked.docs) d.reference]);
    } else if (previous.classId != s.classId) {
      final batch = _db.batch();
      for (final d in linked.docs) {
        batch.update(d.reference, {'classId': s.classId});
      }
      await batch.commit();
    }

    if (previous.classId != s.classId) {
      await _db.collection('threads').doc(s.id).set(
        {'classId': s.classId, 'studentName': s.name, 'parentName': s.parentName},
        SetOptions(merge: true),
      );
    }
  }

  /// Student + त्याचा सगळा संबंधित data (fees, receipts, attendance, chat,
  /// parent login profile) एकत्र काढतो, म्हणजे totals / dashboard चुकत नाहीत.
  Future<void> deleteStudent(String id) async {
    final sRef = _db.collection('students').doc(id);
    final tRef = _db.collection('threads').doc(id);
    final refs = <DocumentReference>[];

    for (final sub in const ['fees', 'receipts']) {
      final q = await sRef.collection(sub).get();
      refs.addAll(q.docs.map((d) => d.reference));
    }
    final att = await _db
        .collection('attendance')
        .where('studentId', isEqualTo: id)
        .get();
    refs.addAll(att.docs.map((d) => d.reference));

    final msgs = await tRef.collection('messages').get();
    refs.addAll(msgs.docs.map((d) => d.reference));
    refs.add(tRef);

    final parents = await _db
        .collection('users')
        .where('studentId', isEqualTo: id)
        .get();
    refs.addAll(parents.docs.map((d) => d.reference));

    refs.add(sRef); // शेवटी student, म्हणजे मध्येच fail झालं तरी retry करता येतो
    await _deleteDocs(refs);
  }

  // =================================================================
  // PARENT ACTIONS
  // =================================================================
  /// Parent चं login profile काढतो; पुढच्या login ला email जुळला तर आपोआप परत link होतो.
  Future<void> unlinkParent(AdminParentUser p) =>
      _db.collection('users').doc(p.uid).delete();

  Future<String?> sendPasswordReset(String email) =>
      AuthService.resetPassword(email);

  // =================================================================
  // ATTENDANCE ACTIONS (Admin दुरुस्ती)
  // =================================================================
  /// Teacher च्या app प्रमाणेच document id ('{day}_{studentId}') वापरतो,
  /// म्हणून Teacher + Parent दोघांना बदल लगेच दिसतो.
  Future<void> setAttendance({
    required String classId,
    required String studentId,
    required String day,
    required String status,
    String reason = '',
  }) async {
    final d = DateTime.parse(day);
    await _db.collection('attendance').doc('${day}_$studentId').set({
      'classId': classId,
      'studentId': studentId,
      'day': day,
      'week': AppState.weekKey(d),
      'status': status,
      'reason': status == 'P' ? '' : reason.trim(),
      'savedBy': uid,
      'savedAt': Timestamp.fromDate(DateTime.now()),
      'editedByAdmin': true,
    });
  }

  // =================================================================
  // FEE ACTIONS
  // =================================================================
  /// `studentIds` मधल्या प्रत्येकाला fee जोडतो (bulk चालतं).
  Future<void> addFee(
      List<String> studentIds,
      String title,
      int amount,
      DateTime? dueDate, {
        bool upcoming = false,
      }) async {
    for (var i = 0; i < studentIds.length; i += 400) {
      final chunk = studentIds.skip(i).take(400);
      final batch = _db.batch();
      for (final id in chunk) {
        final ref = _db.collection('students').doc(id).collection('fees').doc();
        batch.set(ref, {
          'title': title.trim(),
          'amount': amount,
          'status': upcoming ? 'upcoming' : 'due',
          'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
          'order': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });
      }
      await batch.commit();
    }
  }

  /// Paid नसलेली fee edit (title / amount / due date / upcoming-due).
  Future<void> updateFee(
      AdminFee fee, {
        required String title,
        required int amount,
        DateTime? dueDate,
        required bool upcoming,
      }) =>
      _db
          .collection('students')
          .doc(fee.studentId)
          .collection('fees')
          .doc(fee.id)
          .update({
        'title': title.trim(),
        'amount': amount,
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
        'status': upcoming ? 'upcoming' : 'due',
      });

  Future<void> markFeePaid(AdminFee fee, String mode) async {
    final ref = _db.collection('students').doc(fee.studentId);
    final batch = _db.batch();
    batch.update(ref.collection('fees').doc(fee.id), {'status': 'paid'});
    batch.set(ref.collection('receipts').doc(), {
      'title': fee.title,
      'amount': fee.amount,
      'date': Timestamp.fromDate(DateTime.now()),
      'mode': mode,
    });
    await batch.commit();
  }

  Future<void> deleteFee(AdminFee fee) => _db
      .collection('students')
      .doc(fee.studentId)
      .collection('fees')
      .doc(fee.id)
      .delete();

  // =================================================================
  // CIRCULAR / EVENT ACTIONS
  // =================================================================
  /// `classIds` मधल्या प्रत्येक class ला circular पाठवतो.
  Future<void> sendCircular({
    required List<String> classIds,
    required String title,
    required String message,
    required String category,
    required String audienceLabel,
    bool important = false,
    bool needsAck = false,
    DateTime? eventDate,
  }) async {
    final now = DateTime.now();
    final batch = _db.batch();
    for (final cid in classIds) {
      final ref = _db.collection('classes').doc(cid).collection('circulars').doc();
      batch.set(ref, {
        'title': title.trim(),
        'audience': audienceLabel,
        'category': category,
        'families': studentsOfClass(cid).length,
        'sentAt': Timestamp.fromDate(now),
        'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate),
        'attachment': null,
        'message': message.trim(),
        'important': important,
        'scheduledFor': null,
        'needsAck': needsAck,
        'readBy': <String>[],
        'ackedBy': <String>[],
        'classId': cid,
        'createdBy': uid,
        'sentByAdmin': true,
      });
    }
    await batch.commit();
  }

  Future<void> deleteCircular(AdminCircular c) => _db
      .collection('classes')
      .doc(c.classId)
      .collection('circulars')
      .doc(c.id)
      .delete();

  Future<void> addEvent({
    required List<String> classIds,
    required String title,
    required String category,
    required DateTime date,
    String note = '',
  }) async {
    final batch = _db.batch();
    for (final cid in classIds) {
      final ref = _db.collection('classes').doc(cid).collection('events').doc();
      batch.set(ref, {
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'title': title.trim(),
        'category': category,
        'note': note.trim(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteEvent(AdminEvent e) => _db
      .collection('classes')
      .doc(e.classId)
      .collection('events')
      .doc(e.id)
      .delete();

  // =================================================================
  // LEAVE REQUESTS  (classes/{classId}/leaves/{id})
  // Admin ला Firestore rules मध्ये leaves वर पूर्ण read/write आहे.
  // =================================================================
  DocumentReference<Map<String, dynamic>> _leaveRef(AdminLeave l) => _db
      .collection('classes')
      .doc(l.classId)
      .collection('leaves')
      .doc(l.id);

  /// Admin: अर्ज approve / decline करतो (optional note सहित).
  Future<void> decideLeave(AdminLeave l,
      {required bool approved, String note = ''}) =>
      _leaveRef(l).update({
        'status': approved ? 'approved' : 'declined',
        'teacherNote': note.trim(),
        'decidedAt': Timestamp.fromDate(DateTime.now()),
        'decidedBy': uid,
        'decidedByRole': 'admin',
      });

  /// Admin: घेतलेला निर्णय मागे घेऊन अर्ज पुन्हा pending करतो.
  Future<void> reopenLeave(AdminLeave l) => _leaveRef(l).update({
    'status': 'pending',
    'teacherNote': '',
    'decidedAt': FieldValue.delete(),
    'decidedBy': FieldValue.delete(),
    'decidedByRole': FieldValue.delete(),
  });

  Future<void> deleteLeave(AdminLeave l) => _leaveRef(l).delete();

  // =================================================================
  // EXTRA READ HELPERS (dashboard / diary / photos / chat)
  // =================================================================
  int get pendingTeachersCount => teachers.where((t) => !t.approved).length;

  /// आज diary publish केलेल्या classes.
  Set<String> get classesWithDiaryToday {
    final t = DateTime.now();
    return diaries
        .where((d) => AppState.sameDay(d.date, t))
        .map((d) => d.classId)
        .toSet();
  }

  int get photosTodayCount {
    final t = DateTime.now();
    return photos.where((p) => AppState.sameDay(p.sentAt, t)).length;
  }

  /// Teacher ने उत्तर न दिलेले (unread) parent messages.
  int get teacherUnreadTotal =>
      threads.fold<int>(0, (n, t) => n + t.teacherUnread);

  List<AdminLeave> get pendingLeaves =>
      leaves.where((l) => l.status == 'pending').toList();

  /// आज approved रजेवर असलेल्या मुलांचे ids.
  Set<String> get onLeaveStudentIds {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return leaves.where((l) {
      if (l.status != 'approved' || l.fromDate == null || l.toDate == null) {
        return false;
      }
      final f = DateTime(l.fromDate!.year, l.fromDate!.month, l.fromDate!.day);
      final t = DateTime(l.toDate!.year, l.toDate!.month, l.toDate!.day);
      return !today.isBefore(f) && !today.isAfter(t);
    }).map((l) => l.studentId).toSet();
  }

  // =================================================================
  // TEACHER EDIT
  // =================================================================
  Future<void> updateTeacher(
      AdminTeacher t, {
        required String name,
        required String phone,
        required String employeeId,
        required String schoolName,
      }) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(t.uid), {
      'name': name.trim(),
      'phone': phone.trim(),
      'employeeId': employeeId.trim(),
      'schoolName': schoolName.trim(),
    });
    if (t.classId.isNotEmpty) {
      final cls = classes.where((c) => c.id == t.classId).toList();
      // class card वरचं नाव फक्त याच teacher चं असेल तरच बदलतो.
      if (cls.isNotEmpty && cls.first.teacherUid == t.uid) {
        batch.set(
          _db.collection('classes').doc(t.classId),
          {'teacherName': name.trim()},
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  // =================================================================
  // CIRCULAR / EVENT EDIT
  // =================================================================
  Future<void> updateCircular(
      AdminCircular c, {
        required String title,
        required String message,
        required String category,
        required bool important,
        required bool needsAck,
        DateTime? eventDate,
      }) =>
      _db
          .collection('classes')
          .doc(c.classId)
          .collection('circulars')
          .doc(c.id)
          .update({
        'title': title.trim(),
        'message': message.trim(),
        'category': category,
        'important': important,
        'needsAck': needsAck,
        'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate),
        'editedByAdmin': true,
      });

  Future<void> updateEvent(
      AdminEvent e, {
        required String title,
        required String category,
        required DateTime date,
        String note = '',
      }) =>
      _db
          .collection('classes')
          .doc(e.classId)
          .collection('events')
          .doc(e.id)
          .update({
        'title': title.trim(),
        'category': category,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'note': note.trim(),
      });

  // =================================================================
  // DIARY / PHOTOS / CHAT ACTIONS
  // =================================================================
  Future<void> deleteDiary(AdminDiary d) => _db
      .collection('classes')
      .doc(d.classId)
      .collection('diary')
      .doc(d.id)
      .delete();

  /// एका photo batch (किंवा एकच photo) चे सर्व documents काढतो.
  Future<void> deletePhotos(List<AdminPhoto> list) => _deleteDocs([
    for (final p in list)
      _db
          .collection('classes')
          .doc(p.classId)
          .collection('photos')
          .doc(p.id),
  ]);

  Future<void> deleteMessage(String studentId, String messageId) => _db
      .collection('threads')
      .doc(studentId)
      .collection('messages')
      .doc(messageId)
      .delete();

  /// Conversation चे सर्व messages + thread काढतो.
  Future<void> clearThread(String studentId) async {
    final tRef = _db.collection('threads').doc(studentId);
    final msgs = await tRef.collection('messages').get();
    await _deleteDocs([...msgs.docs.map((d) => d.reference), tRef]);
  }

  // =================================================================
  // ADMIN PROFILE
  // =================================================================
  Future<void> updateAdminProfile({
    required String name,

    required String school,
  }) async {
    await _db.collection('users').doc(uid).update({
      'name': name.trim(),
      'schoolName': school.trim(),
    });
    adminName = name.trim().isEmpty ? 'Admin' : name.trim();
    schoolName = school.trim();
    notifyListeners();
  }
}