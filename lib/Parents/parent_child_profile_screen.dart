import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/parent_widgets.dart';
import 'parent_home_screen.dart' show ParentColors;

/// P6 · Child Profile
///
/// Features:
///  - Back arrow (same as Photos / Diary / Circulars / Fees)
///  - Hero card with avatar, name, class, roll no and age
///  - Basic details grid (DOB, blood group, gender, class, teacher, roll no)
///  - Allergies & health note (highlighted + copy)
///  - Parents & emergency contacts (copy number)
///  - Authorised pickup card
///  - Copy full profile, request-a-change sheet
class ParentChildProfileScreen extends StatelessWidget {
  const ParentChildProfileScreen({super.key, this.onBack});

  /// Back arrow action. Used as a tab it goes back to Home;
  /// when pushed as a normal screen it just closes the screen.
  final VoidCallback? onBack;

  static const _redFg = Color(0xFFD9564F);
  static const _redBorder = Color(0xFFF5C9C5);
  static const _orangeFg = Color(0xFFD9822B);

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

            return Column(
              children: [
                _header(context, s),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _hero(s, c, now),
                      const SizedBox(height: 14),
                      _basicDetails(s, c),
                      if (c.allergyNote.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _allergyCard(context, c),
                      ],
                      const SizedBox(height: 14),
                      _contactsCard(context, c),
                      if (c.pickupNote.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _pickupCard(c),
                      ],
                      const SizedBox(height: 16),
                      _changeButton(context),
                      const SizedBox(height: 12),
                      _note(),
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

  // ---------- header (back arrow + title + copy + edit) ----------
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Child Profile',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.child.className} · ${s.child.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.muted,
                  ),
                ),
              ],
            ),
          ),
          _roundBtn(
            Icons.copy_rounded,
                () => _copyProfile(context, s),
            tooltip: 'Copy profile',
          ),
          const SizedBox(width: 8),
          _roundBtn(
            Icons.edit_outlined,
                () => _requestChange(context),
            tooltip: 'Request a change',
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

  // ---------- hero ----------
  Widget _hero(AppState s, ChildInfo c, DateTime now) {
    Widget pill(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800)),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ParentColors.primary, ParentColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332B8FDB),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x66FFFFFF), width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              initialsOf(c.name),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: ParentColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${c.className} · Roll No. ${c.rollNo}',
                  style: const TextStyle(
                      color: Color(0xFFEAF5FD), fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    pill('Age ${c.ageLabel(now)}'),
                    pill(c.gender),
                    pill(c.bloodGroup),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- basic details ----------
  Widget _basicDetails(AppState s, ChildInfo c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.badge_rounded, 'Basic details'),
          const SizedBox(height: 12),
          Row(
            children: [
              _box(Icons.cake_rounded, 'Date of birth', _dob(c)),
              const SizedBox(width: 10),
              _box(Icons.bloodtype_rounded, 'Blood group', c.bloodGroup),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _box(Icons.school_rounded, 'Class', c.className),
              const SizedBox(width: 10),
              _box(Icons.person_pin_rounded, 'Class teacher', s.teacherName),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _box(Icons.tag_rounded, 'Roll number', '${c.rollNo}'),
              const SizedBox(width: 10),
              _box(Icons.wc_rounded, 'Gender', c.gender),
            ],
          ),
        ],
      ),
    );
  }

  Widget _box(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: ParentColors.tintStrong,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: ParentColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10,
                          color: ParentColors.muted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.dark)),
                ],
              ),
            ),
          ],
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
  Widget _changeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _requestChange(context),
        icon: const Icon(Icons.edit_note_rounded, size: 20),
        label: const Text('Request a profile change'),
        style: OutlinedButton.styleFrom(
          foregroundColor: ParentColors.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: ParentColors.border),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
          const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
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