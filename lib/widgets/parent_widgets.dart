import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

// ---- Photo placeholder रंग (Firebase नंतर खरे फोटो येतील) ----
const List<Color> kPhotoColors = [
  Color(0xFFFFE0D9),
  Color(0xFFFFF0D9),
  Color(0xFFE3F1FF),
  Color(0xFFDDF2EC),
];
const List<Color> kPhotoIconColors = [
  Color(0xFFE8A596),
  Color(0xFFE6B66A),
  Color(0xFF8FB8E8),
  Color(0xFF7DBFAE),
];

// Category रंग (Circulars + Calendar मध्ये common)
const Map<String, Color> kCategoryBg = {
  'Notice': Color(0xFFE3F1FF),
  'Holiday': Color(0xFFFFE7E5),
  'Meeting': Color(0xFFE3F1FF),
  'Event': Color(0xFFDDF2EC),
  'Celebration': Color(0xFFFFF0D9),
};
const Map<String, Color> kCategoryFg = {
  'Notice': Color(0xFF3F7FC4),
  'Holiday': Color(0xFFD9564F),
  'Meeting': Color(0xFF3F7FC4),
  'Event': Color(0xFF2F8877),
  'Celebration': Color(0xFFD9822B),
};
const Map<String, IconData> kCategoryIcon = {
  'Notice': Icons.campaign_rounded,
  'Holiday': Icons.beach_access_rounded,
  'Meeting': Icons.groups_rounded,
  'Event': Icons.event_rounded,
  'Celebration': Icons.celebration_rounded,
};

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.colorIndex,
    this.onTap,
    this.radius = 14,
  });

  final int colorIndex;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final i = colorIndex % kPhotoColors.length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          color: kPhotoColors[i],
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: Icon(Icons.image_outlined, color: kPhotoIconColors[i]),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyBox extends StatelessWidget {
  const EmptyBox(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.muted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

String initialsOf(String name) => name
    .split(' ')
    .where((p) => p.isNotEmpty)
    .map((p) => p[0])
    .take(2)
    .join()
    .toUpperCase();

/// 6000 → ₹6,000   |   125000 → ₹1,25,000  (Indian grouping)
String rupees(int amount) {
  final s = amount.abs().toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

/// फोन मध्ये (मुलानुसार) छोटे choices save करण्यासाठी:
/// Diary चे "done / packed" ticks आणि Photos चे favourites.
class ParentPrefs {
  static Future<Set<String>> load(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(key) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> save(String key, Set<String> values) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(key, values.toList());
    } catch (_) {}
  }
}