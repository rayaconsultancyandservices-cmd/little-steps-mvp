import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/app_state.dart';

/// Firebase Authentication + user profile (Teacher / Parent).
/// सर्व methods error असल्यास मराठी-friendly English text देतात, यशस्वी झाल्यास `null`.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------
  static String _email(String v) => v.trim().toLowerCase();

  /// 'Little Steps School' + 'Nursery A' -> 'little-steps-school_nursery-a'
  static String classIdFor(String school, String className) {
    String slug(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${slug(school)}_${slug(className)}';
  }

  static String _message(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Wrong email or password.';
        case 'email-already-in-use':
          return 'This email is already registered. Please login.';
        case 'weak-password':
          return 'Password is too weak (minimum 6 characters).';
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

  // ------------------------------------------------------------------
  // TEACHER
  // ------------------------------------------------------------------
  static Future<String?> registerTeacher({
    required String name,
    required String email,
    required String phone,
    required String school,
    required String employeeId,
    required String className,
    required String password,
  }) async {
    User? user;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _email(email),
        password: password,
      );
      user = cred.user!;
      final classId = classIdFor(school, className);

      await _db.collection('users').doc(user.uid).set({
        'role': 'teacher',
        'name': name.trim(),
        'email': _email(email),
        'phone': phone.trim(),
        'schoolName': school.trim(),
        'employeeId': employeeId.trim(),
        'className': className,
        'classId': classId,
        'createdAt': Timestamp.now(),
      });

      await _db.collection('classes').doc(classId).set({
        'teacherName': name.trim(),
        'className': className,
        'schoolName': school.trim(),
        'teacherUid': user.uid,
      }, SetOptions(merge: true));

      // Register झाल्यावर login screen वर परत जातो, म्हणून sign out.
      await _auth.signOut();
      return null;
    } catch (e) {
      // अर्धवट बनलेलं account काढून टाकतो म्हणजे परत register करता येईल.
      try {
        await user?.delete();
      } catch (_) {}
      return _message(e);
    }
  }

  static Future<String?> loginTeacher(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _email(email),
        password: password,
      );
      final err = await AppState.instance.startSession();
      if (err != null) {
        await signOut();
        return err;
      }
      if (!AppState.instance.isTeacher) {
        await signOut();
        return 'This is not a Teacher account. Please use the Parent app.';
      }
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  // ------------------------------------------------------------------
  // PARENT
  // ------------------------------------------------------------------
  /// Parent login. पहिल्यांदा login करताना, teacher ने student मध्ये टाकलेला
  /// `parentEmail` हाच email असेल तर account आपोआप बनतो आणि मुलाशी link होतो.
  static Future<String?> loginParent(String email, String password) async {
    final mail = _email(email);
    try {
      try {
        await _auth.signInWithEmailAndPassword(email: mail, password: password);
      } on FirebaseAuthException catch (e) {
        final maybeNew = e.code == 'invalid-credential' ||
            e.code == 'user-not-found' ||
            e.code == 'wrong-password';
        if (!maybeNew) rethrow;

        // नवीन parent आहे का? account बनवून बघतो.
        try {
          await _auth.createUserWithEmailAndPassword(
              email: mail, password: password);
        } on FirebaseAuthException catch (e2) {
          // email आधीच आहे => password चुकला
          if (e2.code == 'email-already-in-use' || e2.code == 'weak-password') {
            return 'Wrong email or password.';
          }
          rethrow;
        }
      }

      final user = _auth.currentUser!;
      final udoc = await _db.collection('users').doc(user.uid).get();
      if (!udoc.exists) {
        final linkErr = await _linkParent(user, mail);
        if (linkErr != null) {
          // link नसेल तर नवीन बनलेलं account काढतो.
          try {
            await user.delete();
          } catch (_) {
            await _auth.signOut();
          }
          return linkErr;
        }
      }

      final err = await AppState.instance.startSession();
      if (err != null) {
        await signOut();
        return err;
      }
      if (!AppState.instance.isParent) {
        await signOut();
        return 'This is not a Parent account. Please use the Teacher app.';
      }
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  /// Parent च्या email वरून student शोधून `users/{uid}` बनवतो.
  static Future<String?> _linkParent(User user, String mail) async {
    final q = await _db
        .collection('students')
        .where('parentEmail', isEqualTo: mail)
        .limit(1)
        .get();
    if (q.docs.isEmpty) {
      return 'No student is linked to this email. '
          'Please ask the teacher to add your email.';
    }
    final s = q.docs.first;
    final d = s.data();
    await _db.collection('users').doc(user.uid).set({
      'role': 'parent',
      'name': (d['parentName'] ?? '') as String,
      'email': mail,
      'studentId': s.id,
      'classId': (d['classId'] ?? '') as String,
      'createdAt': Timestamp.now(),
    });
    return null;
  }

  // ------------------------------------------------------------------
  // COMMON
  // ------------------------------------------------------------------
  static Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: _email(email));
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  static Future<void> signOut() async {
    await AppState.instance.endSession();
    await _auth.signOut();
  }

  /// Splash screen वर: आधी login केलेला असेल तर थेट home. true = session चालू झाला.
  static Future<bool> restoreSession(String expectedRole) async {
    try {
      if (_auth.currentUser == null) return false;
      final err = await AppState.instance.startSession();
      if (err != null) return false;
      return AppState.instance.role == expectedRole;
    } catch (_) {
      return false;
    }
  }
}