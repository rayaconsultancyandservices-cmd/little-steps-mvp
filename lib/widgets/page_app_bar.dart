import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// सर्व screens साठी common top bar: back arrow + title + लहान subtitle (design प्रमाणे).
AppBar buildPageAppBar({
  required String title,
  String? subtitle,
  VoidCallback? onBack,
  List<Widget>? actions,
}) {
  return AppBar(
    automaticallyImplyLeading: false,
    leading: onBack == null
        ? null
        : IconButton(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.muted,
            ),
          ),
      ],
    ),
    actions: actions,
  );
}