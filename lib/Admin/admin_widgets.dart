
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';

// =====================================================================
// Little Steps - Modern Admin Web Panel
// Shared UI widgets for all Admin screens
// =====================================================================

class AdminColors {
  static const Color primary = AppColors.primary;
  static const Color dark = Color(0xFF24313D);
  static const Color muted = Color(0xFF7B8794);
  static const Color border = Color(0xFFE8EEEB);
  static const Color pageBg = Color(0xFFF3F7F6);
  static const Color surface = Colors.white;

  static const Color green = Color(0xFF269B73);
  static const Color red = Color(0xFFE36B61);
  static const Color orange = Color(0xFFD99437);
  static const Color blue = Color(0xFF4786C7);
  static const Color purple = Color(0xFF7761C5);

  static const Color greenLight = Color(0xFFE6F5EF);
  static const Color blueLight = Color(0xFFEAF2FC);
  static const Color orangeLight = Color(0xFFFFF3E1);
  static const Color purpleLight = Color(0xFFF0ECFA);
  static const Color redLight = Color(0xFFFFEDEC);
}

String fmtDate(DateTime? d) =>
    d == null ? '—' : '${d.day} ${AppState.monthShort(d.month)} ${d.year}';

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

// =====================================================================
// SNACKBAR
// =====================================================================

void adminSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: error ? AdminColors.red : AdminColors.dark,
        behavior: SnackBarBehavior.floating,
        width: 420,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
}

// =====================================================================
// CONFIRMATION DIALOG
// =====================================================================

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 19,
          color: AdminColors.dark,
        ),
      ),
      content: SizedBox(
        width: 380,
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AdminColors.muted,
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminColors.dark,
            side: const BorderSide(color: AdminColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
            danger ? AdminColors.red : AdminColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );

  return ok == true;
}

// =====================================================================
// COMMON ADMIN PAGE
// =====================================================================

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
        constraints: const BoxConstraints(maxWidth: 1520),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 650;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 24,
                compact ? 17 : 22,
                compact ? 14 : 24,
                32,
              ),
              children: [
                Wrap(
                  spacing: 18,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? constraints.maxWidth : 600,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: compact ? 21 : 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                              color: AdminColors.dark,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AdminColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (actions.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                child,
              ],
            );
          },
        ),
      ),
    );
  }
}

// =====================================================================
// COMMON ADMIN CARD
// =====================================================================

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AdminColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24313D).withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
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
            const SizedBox(height: 17),
            const Divider(
              height: 1,
              color: AdminColors.border,
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

// =====================================================================
// DASHBOARD STATISTIC CARD
// =====================================================================

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
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: AdminColors.dark.withValues(alpha: 0.03),
            blurRadius: 11,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                height: 33,
                width: 33,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Icon(
                Icons.insights_rounded,
                color: color.withValues(alpha: 0.65),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: AdminColors.dark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AdminColors.muted,
            ),
          ),
          if (note != null && note!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// STATUS CHIP
// =====================================================================

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, this.color, {super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// =====================================================================
// EMPTY STATE
// =====================================================================

class EmptyState extends StatelessWidget {
  const EmptyState(
      this.text, {
        super.key,
        this.icon = Icons.inbox_rounded,
      });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                color: AdminColors.greenLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 35,
                color: AdminColors.primary,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminColors.muted,
                fontSize: 13,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ERROR BANNER
// =====================================================================

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AdminColors.redLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AdminColors.red.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AdminColors.red,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: AdminColors.red,
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// ADMIN DATA TABLE
// =====================================================================

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
    if (rows.isEmpty) {
      return EmptyState(emptyText);
    }

    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: c.maxWidth,
            ),
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 50,
              dataRowMaxHeight: 62,
              columnSpacing: 20,
              horizontalMargin: 10,
              dividerThickness: 0.6,
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFF6F9F8),
              ),
              headingTextStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AdminColors.muted,
                letterSpacing: 0.55,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12,
                color: AdminColors.dark,
              ),
              columns: [
                for (final t in columns)
                  DataColumn(
                    label: Text(t.toUpperCase()),
                  ),
              ],
              rows: rows,
            ),
          ),
        );
      },
    );
  }
}

// =====================================================================
// TABLE CELL TEXT
// =====================================================================

DataCell cellText(
    String text, {
      bool bold = false,
      Color? color,
    }) {
  return DataCell(
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Text(
        text.isEmpty ? '—' : text,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: color ?? AdminColors.dark,
        ),
      ),
    ),
  );
}

// =====================================================================
// SEARCH FIELD
// =====================================================================

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
        style: const TextStyle(
          fontSize: 13,
          color: AdminColors.dark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 12,
            color: AdminColors.muted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AdminColors.muted,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 14,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
            ),
            onPressed: () {
              controller.clear();
              onChanged('');
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: AdminColors.border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: AdminColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(
              color: AdminColors.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// DIALOG FORM FIELD
// =====================================================================

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
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 13,
        color: AdminColors.dark,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFFAFCFB),
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AdminColors.muted,
        ),
        hintStyle: const TextStyle(
          fontSize: 12,
          color: AdminColors.muted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AdminColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AdminColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AdminColors.primary,
            width: 1.5,
          ),
        ),
      ),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty)
              ? 'Required'
              : null
              : null),
    ),
  );
}

// =====================================================================
// PRIMARY BUTTON STYLE
// =====================================================================

ButtonStyle adminPrimaryButton() => FilledButton.styleFrom(
  backgroundColor: AdminColors.primary,
  foregroundColor: Colors.white,
  minimumSize: const Size(0, 46),
  padding: const EdgeInsets.symmetric(horizontal: 20),
  elevation: 0,
  textStyle: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
);

// =====================================================================
// ADMIN DROPDOWN
// =====================================================================

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
        style: const TextStyle(
          fontSize: 12,
          color: AdminColors.dark,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(
            fontSize: 12,
            color: AdminColors.muted,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AdminColors.border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AdminColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AdminColors.primary,
              width: 1.5,
            ),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}


// =====================================================================
// ADDITIONAL SHARED COMPONENTS
// These widgets are additive. Existing Admin screen APIs are unchanged.
// =====================================================================

/// Responsive grid for dashboard cards and summary panels.
class AdminResponsiveGrid extends StatelessWidget {
  const AdminResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 210,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < minItemWidth
            ? 1
            : ((width + spacing) / (minItemWidth + spacing)).floor().clamp(1, 6).toInt();
        final itemWidth =
            (width - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Consistent heading for sections inside an Admin screen.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: AdminColors.greenLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: AdminColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 11),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AdminColors.dark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AdminColors.muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Standard loading state for Admin pages and panels.
class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({
    super.key,
    this.message = 'Loading data...',
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 22 : 55,
        horizontal: 16,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 27,
              width: 27,
              child: CircularProgressIndicator(
                strokeWidth: 2.7,
                color: AdminColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable rounded icon action.
class AdminIconAction extends StatelessWidget {
  const AdminIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AdminColors.muted;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor ?? AdminColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 37,
            width: 37,
            child: Icon(
              icon,
              size: 18,
              color: onPressed == null
                  ? AdminColors.muted.withValues(alpha: 0.45)
                  : foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable avatar for teacher, parent and student lists.
class AdminAvatar extends StatelessWidget {
  const AdminAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.backgroundColor,
    this.foregroundColor,
    this.imageUrl,
  });

  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final cleanName = name.trim();
    final initial = cleanName.isEmpty ? '?' : cleanName[0].toUpperCase();

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? AdminColors.greenLight,
      foregroundImage: imageUrl == null || imageUrl!.trim().isEmpty
          ? null
          : NetworkImage(imageUrl!),
      child: imageUrl != null && imageUrl!.trim().isNotEmpty
          ? null
          : Text(
        initial,
        style: TextStyle(
          color: foregroundColor ?? AdminColors.primary,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Standard outlined button for secondary actions.
ButtonStyle adminSecondaryButton() => OutlinedButton.styleFrom(
  foregroundColor: AdminColors.dark,
  backgroundColor: Colors.white,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 17),
  side: const BorderSide(color: AdminColors.border),
  elevation: 0,
  textStyle: const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
);

/// Standard destructive action button.
ButtonStyle adminDangerButton() => FilledButton.styleFrom(
  backgroundColor: AdminColors.red,
  foregroundColor: Colors.white,
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 17),
  elevation: 0,
  textStyle: const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
);
