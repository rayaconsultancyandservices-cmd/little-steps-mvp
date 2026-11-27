import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/parent_widgets.dart';
import 'parent_home_screen.dart' show ParentColors;

/// P6 · Child Profile  (अधिक आकर्षक आणि खरा दिसणारा layout)
///
/// रंग आणि background पूर्वीसारखेच आहेत. फक्त मांडणी सुधारली आहे:
///  - Hero card: ring असलेला मोठा फोटो, नाव, class / roll / age / blood pills
///    आणि "Call parent" + "Request change" बटणे
///  - Child details कार्ड (दोन-दोन tiles), Birth date कार्ड (वाढदिवस जवळ आला की highlight)
///  - Parent / Guardian कार्ड: नाव, email (copy), phone (call)
///  - Allergy, Emergency contacts, Authorised pickup कार्ड्स
///  - Change password, "Joined" तारीख
///  - प्रत्येक section हळूहळू वर सरकत दिसतो (fade + slide)
class ParentChildProfileScreen extends StatelessWidget {
  const ParentChildProfileScreen({super.key, this.onBack});

  /// Back arrow action. Used as a tab it goes back to Home;
  /// when pushed as a normal screen it just closes the screen.
  final VoidCallback? onBack;

  static const _redFg = Color(0xFFD9564F);
  static const _redBorder = Color(0xFFF5C9C5);
  static const _orangeFg = Color(0xFFD9822B);

  static const _monthsFull = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // फोटो वारंवार decode होऊ नये म्हणून छोटा cache.
  static String _cacheKey = '';
  static MemoryImage? _cacheImg;

  static MemoryImage? _photo(ChildInfo c) {
    final data = c.facePhoto;
    if (data.isEmpty) return null;
    final key = '${data.length}:${data.hashCode}';
    if (key == _cacheKey) return _cacheImg;
    try {
      final comma = data.indexOf(',');
      final raw = comma < 0 ? data : data.substring(comma + 1);
      _cacheImg = MemoryImage(base64Decode(raw));
      _cacheKey = key;
      return _cacheImg;
    } catch (_) {
      _cacheKey = key;
      _cacheImg = null;
      return null;
    }
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: AppState.instance,
          builder: (context, _) {
            final s = AppState.instance;
            final c = s.child;
            final now = DateTime.now();
            final loading = c.id.isEmpty && c.name.isEmpty;

            return Column(
              children: [
                _header(context, s),
                Expanded(
                  child: loading
                      ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: ParentColors.primary),
                        ),
                        SizedBox(height: 12),
                        Text('Loading profile…',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: ParentColors.muted)),
                      ],
                    ),
                  )
                      : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                    children: [
                      _appear(0, _hero(context, c, now)),
                      const SizedBox(height: 14),
                      _appear(1, _detailsCard(s, c)),
                      const SizedBox(height: 14),
                      _appear(2, _birthCard(c, now)),
                      const SizedBox(height: 14),
                      _appear(3, _parentCard(context, c)),
                      if (c.allergyNote.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _appear(4, _allergyCard(context, c)),
                      ],
                      const SizedBox(height: 14),
                      _appear(5, _contactsCard(context, c)),
                      if (c.pickupNote.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _appear(6, _pickupCard(c)),
                      ],
                      const SizedBox(height: 16),
                      _passwordButton(context),
                      const SizedBox(height: 14),
                      _note(),
                      const SizedBox(height: 18),
                      _joined(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// प्रत्येक section हळूहळू वर सरकत येतो.
  Widget _appear(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c),
      ),
      child: child,
    );
  }

  // ---------- header (back arrow + centered title + copy) ----------
  Widget _roundBtn(IconData icon, VoidCallback? onTap, {String? tooltip}) {
    final enabled = onTap != null;
    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ParentColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x142B8FDB),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 16, color: ParentColors.dark),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  Widget _header(BuildContext context, AppState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          _roundBtn(
            Icons.arrow_back_ios_new_rounded,
            onBack ?? () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Child Profile',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: ParentColors.dark,
                ),
              ),
            ),
          ),
          _roundBtn(
            Icons.copy_rounded,
                () => _copyProfile(context, s),
            tooltip: 'Copy profile',
          ),
        ],
      ),
    );
  }

  Future<void> _copyProfile(BuildContext context, AppState s) async {
    final c = s.child;
    final b = StringBuffer()
      ..writeln('Child profile')
      ..writeln('Name: ${c.name}')
      ..writeln('Class: ${c.className} (Roll no. ${c.rollNo})')
      ..writeln('Date of birth: ${_dob(c)}')
      ..writeln('Blood group: ${c.bloodGroup}')
      ..writeln('Gender: ${c.gender}');
    if (c.parentName.isNotEmpty) b.writeln('Parent: ${c.parentName}');
    final mail = _parentEmail(c);
    if (mail.isNotEmpty) b.writeln('Email: $mail');
    if (c.allergyNote.isNotEmpty) b.writeln('Allergies: ${c.allergyNote}');
    b.writeln();
    for (final p in c.contacts) {
      b.writeln('${p.name} (${p.relation}): +91 ${p.phone}');
    }
    if (c.pickupNote.isNotEmpty) b.writeln(c.pickupNote);
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (context.mounted) showSnack(context, 'Profile copied');
  }

  String _dob(ChildInfo c) =>
      '${c.dob.day} ${AppState.monthShort(c.dob.month)} ${c.dob.year}';

  /// Parent चा email: student मध्ये असेल तर तो, नाहीतर login चा email.
  String _parentEmail(ChildInfo c) {
    if (c.parentEmail.trim().isNotEmpty) return c.parentEmail.trim();
    return FirebaseAuth.instance.currentUser?.email ?? '';
  }

  /// पहिला उपलब्ध contact नंबर (नसेल तर '').
  String _firstPhone(ChildInfo c) {
    for (final p in c.contacts) {
      if (p.phone.trim().isNotEmpty) return p.phone.trim();
    }
    return '';
  }

  // ---------- hero card ----------
  Widget _hero(BuildContext context, ChildInfo c, DateTime now) {
    final photo = _photo(c);
    final phone = _firstPhone(c);

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        // ring (gradient border)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ParentColors.primary, ParentColors.primaryLight],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x332B8FDB),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: ParentColors.tintStrong,
              backgroundImage: photo,
              child: photo == null
                  ? Text(
                initialsOf(c.name),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: ParentColors.primary,
                ),
              )
                  : null,
            ),
          ),
        ),
        // student badge
        Positioned(
          right: 2,
          bottom: 4,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: ParentColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: const Icon(Icons.school_rounded,
                size: 15, color: Colors.white),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          photo == null
              ? avatar
              : GestureDetector(
            onTap: () => _showPhoto(context, photo),
            child: avatar,
          ),
          const SizedBox(height: 14),
          Text(
            c.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: ParentColors.dark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (c.className.isNotEmpty)
                _pill(Icons.school_outlined, c.className),
              if (c.rollNo > 0) _pill(Icons.tag_rounded, 'Roll ${c.rollNo}'),
              _pill(Icons.cake_outlined, c.ageLabel(now)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (phone.isNotEmpty) ...[
                Expanded(
                  child: _actionBtn(
                    Icons.call_rounded,
                    'Call parent',
                        () => _call(context, phone),
                    filled: true,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _actionBtn(
                  Icons.edit_note_rounded,
                  'Request change',
                      () => _requestChange(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, {bool red = false}) {
    final fg = red ? _redFg : ParentColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: red ? AppColors.redLight : ParentColors.tint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: red ? _redBorder : ParentColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: red ? _redFg : ParentColors.dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap,
      {bool filled = false}) {
    return SizedBox(
      height: 44,
      child: filled
          ? ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: ParentColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
          const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      )
          : OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: ParentColors.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: ParentColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
          const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  void _showPhoto(BuildContext context, ImageProvider photo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(18),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: InteractiveViewer(
                child: Image(image: photo, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: _roundBtn(Icons.close_rounded, () => Navigator.pop(ctx),
                  tooltip: 'Close'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- child details card ----------
  Widget _detailsCard(AppState s, ChildInfo c) {
    final t = s.teacherName.trim();
    // 'Teacher' हे default नाव आहे; खरं नाव अजून आलं नसेल तर "Not assigned yet".
    final teacher = (t.isEmpty || t == 'Teacher') ? 'Not assigned yet' : t;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.badge_rounded, 'Child details'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _tile(Icons.school_rounded, 'Class', c.className)),
              const SizedBox(width: 10),
              Expanded(
                child: _tile(Icons.tag_rounded, 'Roll number',
                    c.rollNo > 0 ? '${c.rollNo}' : ''),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _tile(Icons.wc_rounded, 'Gender', c.gender)),
              const SizedBox(width: 10),
              Expanded(
                child: _tile(Icons.bloodtype_rounded, 'Blood group',
                    c.bloodGroup),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _tile(Icons.person_pin_rounded, 'Class teacher', teacher),
        ],
      ),
    );
  }

  Widget _iconTile(IconData icon, {double size = 34}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ParentColors.tintStrong,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: size * 0.5, color: ParentColors.primary),
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    final has = value.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _iconTile(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  has ? value.trim() : '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: has ? ParentColors.dark : ParentColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- birth date card ----------
  Widget _birthCard(ChildInfo c, DateTime now) {
    Widget chip(String text, int flex) => Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: ParentColors.dark,
          ),
        ),
      ),
    );

    // पुढचा वाढदिवस किती दिवसांनी.
    final today = DateTime(now.year, now.month, now.day);
    var next = DateTime(now.year, c.dob.month, c.dob.day);
    if (next.isBefore(today)) {
      next = DateTime(now.year + 1, c.dob.month, c.dob.day);
    }
    final days = next.difference(today).inDays;
    final soon = days <= 7;
    final bday = days == 0
        ? 'Birthday today'
        : (days == 1 ? 'Birthday tomorrow' : 'Birthday in $days days');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.cake_rounded, 'Birth date'),
          const SizedBox(height: 12),
          Row(
            children: [
              chip('${c.dob.day}', 2),
              const SizedBox(width: 8),
              chip(_monthsFull[c.dob.month - 1], 4),
              const SizedBox(width: 8),
              chip('${c.dob.year}', 3),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Age ${c.ageLabel(now)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ParentColors.muted,
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: soon
                      ? const Color(0x33F2B233)
                      : ParentColors.tint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.celebration_rounded,
                      size: 14,
                      color: soon ? _orangeFg : ParentColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      bday,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: soon ? _orangeFg : ParentColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- parent / guardian card ----------
  Widget _parentCard(BuildContext context, ChildInfo c) {
    final phone = _firstPhone(c);
    final mail = _parentEmail(c);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.family_restroom_rounded, 'Parent / Guardian'),
          const SizedBox(height: 6),
          _infoRow(context, Icons.person_outline_rounded, 'Name',
              c.parentName),
          const Divider(height: 1, color: AppColors.border),
          _infoRow(
            context,
            Icons.mail_outline_rounded,
            'Email address',
            mail,
            actionIcon: Icons.copy_rounded,
            onAction: mail.isEmpty
                ? null
                : () async {
              await Clipboard.setData(ClipboardData(text: mail));
              if (context.mounted) showSnack(context, 'Email copied');
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          _infoRow(
            context,
            Icons.phone_outlined,
            'Phone number',
            phone.isEmpty ? '' : '+91 $phone',
            actionIcon: Icons.call_rounded,
            onAction: phone.isEmpty ? null : () => _call(context, phone),
            copyValue: phone,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
      BuildContext context,
      IconData icon,
      String label,
      String value, {
        IconData? actionIcon,
        VoidCallback? onAction,
        String? copyValue,
      }) {
    final has = value.trim().isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: !has
          ? null
          : () async {
        await Clipboard.setData(
            ClipboardData(text: (copyValue ?? value).trim()));
        if (context.mounted) showSnack(context, '$label copied');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            _iconTile(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: ParentColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    has ? value.trim() : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: has ? ParentColors.dark : ParentColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (actionIcon != null && onAction != null)
              GestureDetector(
                onTap: onAction,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: ParentColors.tintStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(actionIcon,
                      size: 17, color: ParentColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final ok =
        digits.isNotEmpty && await launchUrl(Uri(scheme: 'tel', path: digits));
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (context.mounted) {
        showSnack(context, 'Could not open the dialer. Number copied: $phone');
      }
    }
  }

  // ---------- Joined (सगळ्यात खाली) ----------
  Widget _joined() {
    final d = FirebaseAuth.instance.currentUser?.metadata.creationTime;
    if (d == null) return const SizedBox.shrink();
    final l = d.toLocal();
    return Center(
      child: Text(
        'Joined ${l.day} ${AppState.monthShort(l.month)} ${l.year}',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: ParentColors.muted,
        ),
      ),
    );
  }

  // ---------- allergy ----------
  Widget _allergyCard(BuildContext context, ChildInfo c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _redBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 18, color: _redFg),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Allergies & health note',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: _redFg)),
              ),
              const StatusChip('Important', bg: Colors.white, fg: _redFg),
            ],
          ),
          const SizedBox(height: 10),
          Text(c.allergyNote,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.text)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: c.allergyNote));
                if (context.mounted) showSnack(context, 'Health note copied');
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 14, color: _redFg),
                  SizedBox(width: 4),
                  Text('Copy',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _redFg)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- contacts ----------
  Widget _contactsCard(BuildContext context, ChildInfo c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.contacts_rounded, 'Parents & emergency contacts'),
          const SizedBox(height: 6),
          if (c.contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('No contacts added yet.',
                  style: TextStyle(fontSize: 12, color: ParentColors.muted)),
            ),
          for (var i = 0; i < c.contacts.length; i++) ...[
            _contactRow(context, c.contacts[i]),
            if (i != c.contacts.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _contactRow(BuildContext context, ParentContact p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.orangeLight,
            child: Text(initialsOf(p.name),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _orangeFg)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: ParentColors.dark)),
                const SizedBox(height: 2),
                Text('${p.relation} · +91 ${p.phone}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: ParentColors.muted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Tap = खरा phone call, long-press = number copy.
          GestureDetector(
            onTap: () async {
              final digits = p.phone.replaceAll(RegExp(r'[^0-9+]'), '');
              final ok = digits.isNotEmpty &&
                  await launchUrl(Uri(scheme: 'tel', path: digits));
              if (!ok && context.mounted) {
                await Clipboard.setData(ClipboardData(text: p.phone));
                if (context.mounted) {
                  showSnack(context,
                      'Could not open the dialer. Number copied: ${p.phone}');
                }
              }
            },
            onLongPress: () async {
              await Clipboard.setData(ClipboardData(text: p.phone));
              if (context.mounted) {
                showSnack(context, '${p.name}’s number copied: ${p.phone}');
              }
            },
            child: Tooltip(
              message: 'Call (long-press to copy)',
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: ParentColors.tintStrong,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_rounded,
                    size: 18, color: ParentColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- pickup ----------
  Widget _pickupCard(ChildInfo c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF7DDB0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.directions_walk_rounded,
                size: 19, color: _orangeFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Authorised pickup',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _orangeFg)),
                const SizedBox(height: 2),
                Text(c.pickupNote,
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: ParentColors.dark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- request change ----------
  Future<void> _changePassword(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ParentChangePasswordSheet(),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Password changed successfully.'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  Widget _passwordButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: () => _changePassword(context),
        icon: const Icon(Icons.lock_reset_rounded, size: 18),
        label: const Text(
          'Change password',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: ParentColors.primary,
          side: const BorderSide(color: ParentColors.border),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _requestChange(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ChangeRequestSheet(),
    );
  }

  // ---------- small pieces ----------
  Widget _cardTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: ParentColors.tintStrong,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: ParentColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: ParentColors.dark)),
        ),
      ],
    );
  }

  Widget _note() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: ParentColors.muted),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Details are maintained by the school office.',
              style: TextStyle(
                  fontSize: 11, color: ParentColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0F14375A),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  );
}

/// "Request a change" — आता खरंच class teacher ला chat मध्ये message म्हणून जातं.
class _ChangeRequestSheet extends StatefulWidget {
  const _ChangeRequestSheet();

  @override
  State<_ChangeRequestSheet> createState() => _ChangeRequestSheetState();
}

class _ChangeRequestSheetState extends State<_ChangeRequestSheet> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _text.text.trim();
    if (msg.isEmpty || _sending) return;
    final s = AppState.instance;
    setState(() => _sending = true);
    try {
      await s.sendMessage(
        s.child.id,
        'Profile change request for ${s.child.name}:\n$msg',
        fromTeacher: false,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Request sent to the class teacher');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      showSnack(context, 'Could not send. Please check your internet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Request a change',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark)),
            const SizedBox(height: 8),
            const Text(
              'Profile changes are approved by the school office. '
                  'Tell us what to update:',
              style: TextStyle(
                  fontSize: 12.5, height: 1.5, color: ParentColors.muted),
            ),
            const SizedBox(height: 12),
            for (final t in const [
              'Phone numbers and emergency contacts',
              'Allergies and health information',
              'Authorised pickup persons',
              'Name or date of birth corrections',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: ParentColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ParentColors.dark)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. New emergency number: 98xxxxxxxx',
                filled: true,
                fillColor: ParentColors.tint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: (_text.text.trim().isEmpty || _sending) ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParentColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: Text(_sending ? 'Sending…' : 'Send to class teacher'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// नवीन: Parent साठी password बदलण्याची bottom sheet.
class _ParentChangePasswordSheet extends StatefulWidget {
  const _ParentChangePasswordSheet();

  @override
  State<_ParentChangePasswordSheet> createState() =>
      _ParentChangePasswordSheetState();
}

class _ParentChangePasswordSheetState
    extends State<_ParentChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, bool visible, VoidCallback toggle) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: ParentColors.tint,
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ParentColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ParentColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ParentColors.primary, width: 1.4),
        ),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(
            visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 19,
            color: ParentColors.muted,
          ),
        ),
      );

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AuthService.changePassword(
      currentPassword: _current.text,
      newPassword: _new.text,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: ParentColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Change password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Enter your current password, then choose a new one.',
                  style: TextStyle(fontSize: 11, color: ParentColors.muted),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _current,
                  obscureText: !_showCurrent,
                  decoration: _dec('Current password', _showCurrent,
                          () => setState(() => _showCurrent = !_showCurrent)),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _new,
                  obscureText: !_showNew,
                  decoration: _dec('New password', _showNew,
                          () => setState(() => _showNew = !_showNew)),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'Minimum 8 characters required';
                    if (!RegExp(r'[A-Z]').hasMatch(v)) {
                      return 'Add at least one uppercase letter';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(v)) {
                      return 'Add at least one number';
                    }
                    if (v == _current.text) {
                      return 'New password must be different';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _confirm,
                  obscureText: !_showNew,
                  decoration: _dec('Confirm new password', _showNew,
                          () => setState(() => _showNew = !_showNew)),
                  validator: (v) =>
                  v != _new.text ? 'Passwords do not match' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ParentColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParentColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Change password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
