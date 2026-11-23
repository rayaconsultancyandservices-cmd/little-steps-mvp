import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';

// =====================================================================
// Admin web panel – common widgets / helpers
// =====================================================================

class AdminColors {
  static const Color primary = AppColors.primary;
  static const Color dark = AppColors.text;
  static const Color muted = AppColors.muted;
  static const Color border = AppColors.border;
  static const Color pageBg = Color(0xFFF5F8F6);
  static const Color green = Color(0xFF269B73);
  static const Color red = Color(0xFFE36B61);
  static const Color orange = Color(0xFFD99437);
  static const Color blue = Color(0xFF4786C7);
  static const Color purple = Color(0xFF7761C5);
}

/// '23 Nov 2026'
String fmtDate(DateTime? d) =>
    d == null ? '—' : '${d.day} ${AppState.monthShort(d.month)} ${d.year}';

/// '₹6,000' / '₹1,25,000' (Indian grouping)
String fmtMoney(int amount) {
  final s = amount.abs().toString();
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return '${amount < 0 ? '-' : ''}₹$out';
}

void adminSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AdminColors.red : AdminColors.dark,
        behavior: SnackBarBehavior.floating,
        width: 420,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

Future<bool> adminConfirm(
    BuildContext context, {
      required String title,
      required String message,
      String confirmText = 'Delete',
      bool danger = true,
    }) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: SizedBox(width: 380, child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? AdminColors.red : AdminColors.primary,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Page header + content (प्रत्येक admin screen याच्यात गुंडाळलेला).
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdminColors.muted,
                      ),
                    ),
                  ],
                ),
                if (actions.isNotEmpty)
                  Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.title,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.dark,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AdminColors.dark,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.muted,
                  ),
                ),
                if (note != null)
                  Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
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
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, this.color, {super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: AdminColors.border),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AdminColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Firestore error (उदा. rules) असल्यास वरती दाखवायचा banner.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AdminColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(color: AdminColors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scroll + full-width DataTable.
class AdminTable extends StatelessWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyText = 'No data yet.',
  });

  final List<String> columns;
  final List<DataRow> rows;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return EmptyState(emptyText);
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: DataTable(
            headingRowHeight: 42,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 60,
            columnSpacing: 28,
            horizontalMargin: 8,
            dividerThickness: 0.6,
            headingTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AdminColors.muted,
              letterSpacing: 0.4,
            ),
            columns: [
              for (final t in columns) DataColumn(label: Text(t.toUpperCase())),
            ],
            rows: rows,
          ),
        ),
      ),
    );
  }
}

DataCell cellText(String text, {bool bold = false, Color? color}) => DataCell(
  ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 240),
    child: Text(
      text.isEmpty ? '—' : text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: color ?? AdminColors.dark,
      ),
    ),
  ),
);

/// Search box (सर्व list screens साठी).
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.width = 300,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: AdminColors.muted),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              controller.clear();
              onChanged('');
            },
          ),
        ),
      ),
    );
  }
}

/// Dialog मधील form field.
Widget dialogField(
    TextEditingController c,
    String label, {
      bool required = false,
      TextInputType? keyboard,
      int maxLines = 1,
      String? hint,
      String? Function(String?)? validator,
    }) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null),
    ),
  );
}

ButtonStyle adminPrimaryButton() => FilledButton.styleFrom(
  backgroundColor: AdminColors.primary,
  foregroundColor: Colors.white,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 18),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

/// Dropdown field जो 'All' सारखा null option सपोर्ट करतो.
class AdminDropdown<T> extends StatelessWidget {
  const AdminDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 220,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        // ignore: deprecated_member_use
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}