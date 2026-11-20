import 'package:flutter/foundation.dart';

class CircularRecord {
  const CircularRecord({
    required this.title,
    required this.audience,
    required this.category,
    required this.families,
    required this.sentAt,
    this.eventDate,
    this.attachment,
  });

  final String title;
  final String audience;
  final String category;
  final int families;
  final DateTime sentAt;
  final DateTime? eventDate;
  final String? attachment;
}

/// सर्व screens मधला common data. Home screen चे badges इथूनच update होतात.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

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

  void saveAttendance({required int present, required int absent}) {
    attendanceSaved = true;
    presentCount = present;
    absentCount = absent;
    notifyListeners();
  }

  void addPhotos(int count) {
    photosToday += count;
    notifyListeners();
  }

  void publishDiary() {
    diaryPublished = true;
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

  // ---------- Date / time helpers ----------
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String dateLabel(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

  static String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String timeLabel(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}