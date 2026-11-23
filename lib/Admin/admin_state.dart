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
  List<AdminFee> fees = [];
  List<AdminCircular> circulars = [];
  List<AdminEvent> events = [];

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
    fees = [];
    circulars = [];
    events = [];
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
    _listen(_db.collectionGroup('fees'), (snap) {
      fees = [for (final d in snap.docs) AdminFee.fromDoc(d)]
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

  Future<void> deleteClass(String classId) =>
      _db.collection('classes').doc(classId).delete();

  // =================================================================
  // TEACHER ACTIONS
  // =================================================================
  /// Teacher ला class assign करतो (users + classes दोन्ही update).
  Future<void> assignTeacher(AdminTeacher t, AdminClass c) async {
    final batch = _db.batch();
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

  Future<void> saveStudent(ChildInfo s, {bool isNew = false}) async {
    if (isNew) {
      await _db.collection('students').add(s.toMap());
    } else {
      await _db.collection('students').doc(s.id).update(s.toMap());
    }
  }

  Future<void> deleteStudent(String id) =>
      _db.collection('students').doc(id).delete();

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
}