import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../widgets/page_app_bar.dart';

/// Teacher साठी: एका मुलाचं पूर्ण profile (read-only).
/// बदल (Step 3): Edit आणि Delete काढलं. मुलाची माहिती बदलणं / काढणं फक्त Admin करतो.
///
/// Teacher app चे रंग/style तेच वापरले आहेत (attendance_screen प्रमाणे):
/// background 0xFFF4F8F7, primary 0xFF168C80, dark 0xFF183B45, muted 0xFF84918D.
///
/// मुलाचा data AppState.students मधून live घेतो (Admin / Teacher ने बदल केला
/// की आपोआप अपडेट होतो). हजेरीचा सारांश Firestore च्या `attendance` मधून
/// फक्त वाचतो; ते लोड झालं नाही तरी बाकीचं profile नीट दिसतं.
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  static const Color primary = Color(0xFF168C80);
  static const Color dark = Color(0xFF183B45);
  static const Color muted = Color(0xFF84918D);
  static const Color green = Color(0xFF269B73);
  static const Color red = Color(0xFFE36B61);
  static const Color orange = Color(0xFFD99437);
  static const Color border = Color(0xFFE5ECE9);

  static const List<Color> headerColors = [
    Color(0xFF104F58),
    Color(0xFF087F79),
    Color(0xFF27B69B),
  ];

  /// हजेरीचा सारांश किती दिवसांचा (मागचे N दिवस).
  static const int _summaryDays = 30;

  bool _loadingAtt = true;
  String? _attError;
  List<_AttEntry> _att = [];

  // Fees सारांश (read-only)
  bool _loadingFees = true;
  String? _feesError;
  List<FeeItem> _fees = [];


  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onState);
    _loadAttendance();
    _loadFees();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  ChildInfo? get _child {
    for (final c in AppState.instance.students) {
      if (c.id == widget.studentId) return c;
    }
    return null;
  }

  // ---------------------------------------------------------------
  // ATTENDANCE (read-only)
  // ---------------------------------------------------------------
  Future<void> _loadAttendance() async {
    setState(() {
      _loadingAtt = true;
      _attError = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('classId', isEqualTo: AppState.instance.classId)
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      final list = <_AttEntry>[];
      for (final d in snap.docs) {
        final x = d.data();
        final date = DateTime.tryParse((x['day'] ?? '') as String);
        if (date == null) continue;
        list.add(_AttEntry(
          date,
          (x['status'] ?? '') as String,
          (x['reason'] ?? '') as String,
        ));
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _att = list;
        _loadingAtt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _attError = 'Could not load attendance history.';
        _loadingAtt = false;
      });
    }
  }

  // ---------------------------------------------------------------
  // FEES (read-only सारांश)
  // ---------------------------------------------------------------
  Future<void> _loadFees() async {
    setState(() {
      _loadingFees = true;
      _feesError = null;
    });
    try {
      final list = await AppState.instance.loadStudentFees(widget.studentId);
      if (!mounted) return;
      setState(() {
        _fees = list;
        _loadingFees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feesError = 'Could not load fees.';
        _loadingFees = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadAttendance(), _loadFees()]);
  }

  List<_AttEntry> get _recent {
    final from = DateTime.now().subtract(const Duration(days: _summaryDays));
    return _att.where((a) => !a.date.isBefore(from)).toList();
  }

  // ---------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------
  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _call(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    var ok = false;
    if (digits.isNotEmpty) {
      try {
        ok = await launchUrl(Uri(scheme: 'tel', path: digits));
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        _snack('Could not open the dialer. Number copied: $phone');
      }
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _dateText(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  String _shortDay(DateTime d) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wd[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final child = _child;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),
      appBar: buildPageAppBar(
        title: 'Student Profile',
        subtitle: AppState.instance.className,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: child == null
          ? _buildNotFound()
          : RefreshIndicator(
        color: primary,
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            _buildHeader(child),
            const SizedBox(height: 12),
            _buildQuickActions(child),
            _buildBasicInfo(child),
            const SizedBox(height: 12),
            _buildHealth(child),
            const SizedBox(height: 12),
            _buildParents(child),
            if (child.pickupNote.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPickup(child),
            ],
            const SizedBox(height: 12),
            _buildAttendance(),
            const SizedBox(height: 12),
            _buildFees(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This student is no longer in your class.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------
  Widget _buildHeader(ChildInfo c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: headerColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          StudentAvatar(child: c, radius: 36, onDark: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.className.isNotEmpty
                      ? c.className
                      : AppState.instance.className,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _headerChip('Roll ${c.rollNo}'),
                    _headerChip(c.ageLabel(DateTime.now())),
                    if (c.gender.isNotEmpty) _headerChip(c.gender),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // QUICK ACTIONS  (Call parent / Copy email)
  // ---------------------------------------------------------------
  String? _primaryPhone(ChildInfo c) {
    for (final p in c.contacts) {
      if (p.phone.trim().isNotEmpty) return p.phone.trim();
    }
    return null;
  }

  Widget _buildQuickActions(ChildInfo c) {
    final phone = _primaryPhone(c);
    final email = c.parentEmail.trim();
    if (phone == null && email.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (phone != null)
            Expanded(
              child: _actionButton(
                icon: Icons.call_rounded,
                label: 'Call parent',
                color: green,
                light: const Color(0xFFE5F5ED),
                onTap: () => _call(phone),
              ),
            ),
          if (phone != null && email.isNotEmpty) const SizedBox(width: 10),
          if (email.isNotEmpty)
            Expanded(
              child: _actionButton(
                icon: Icons.copy_rounded,
                label: 'Copy email',
                color: const Color(0xFF4779C8),
                light: const Color(0xFFEAF1FF),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: email));
                  if (mounted) _snack('Email copied: $email');
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color light,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: light,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // FEES SUMMARY
  // ---------------------------------------------------------------
  Widget _buildFees() {
    return _card(
      title: 'Fees',
      icon: Icons.account_balance_wallet_rounded,
      accent: const Color(0xFF2E9B5E),
      child: _feesBody(),
    );
  }

  String _rupees(int v) => '₹$v';

  Widget _feesBody() {
    if (_loadingFees) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: primary),
          ),
        ),
      );
    }
    if (_feesError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _feesError!,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ),
          TextButton(onPressed: _loadFees, child: const Text('Retry')),
        ],
      );
    }
    if (_fees.isEmpty) {
      return const Text(
        'No fees added for this child yet.',
        style: TextStyle(fontSize: 12, color: muted),
      );
    }

    var paid = 0;
    var due = 0;
    var upcoming = 0;
    for (final f in _fees) {
      switch (f.status) {
        case FeeStatus.paid:
          paid += f.amount;
          break;
        case FeeStatus.due:
          due += f.amount;
          break;
        case FeeStatus.upcoming:
          upcoming += f.amount;
          break;
      }
    }
    final dueItems = _fees.where((f) => f.status == FeeStatus.due).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _feeBox('Paid', _rupees(paid), green, const Color(0xFFE5F5ED)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _feeBox('Due', _rupees(due), red, const Color(0xFFFFEFED)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _feeBox(
                  'Upcoming', _rupees(upcoming), orange, const Color(0xFFFFF3E3)),
            ),
          ],
        ),
        if (dueItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Pending',
            style: TextStyle(
              fontSize: 11.5,
              color: muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final f in dueItems.take(5)) _dueRow(f),
        ],
      ],
    );
  }

  Widget _feeBox(String label, String value, Color color, Color light) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: light,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dueRow(FeeItem f) {
    final due = f.dueDate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: dark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (due != null)
                  Text(
                    'Due ${_dateText(due)}',
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
              ],
            ),
          ),
          Text(
            _rupees(f.amount),
            style: const TextStyle(
              fontSize: 12.5,
              color: red,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // SECTION CARDS
  // ---------------------------------------------------------------
  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    Color accent = primary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final shown = value.trim().isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              shown,
              style: const TextStyle(
                fontSize: 12.5,
                color: dark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(ChildInfo c) {
    return _card(
      title: 'Basic information',
      icon: Icons.badge_rounded,
      child: Column(
        children: [
          _infoRow('Roll no', '${c.rollNo}'),
          _infoRow('Date of birth', _dateText(c.dob)),
          _infoRow('Age', c.ageLabel(DateTime.now())),
          _infoRow('Gender', c.gender),
          _infoRow('Blood group', c.bloodGroup),
        ],
      ),
    );
  }

  Widget _buildHealth(ChildInfo c) {
    final has = c.allergyNote.trim().isNotEmpty;
    return _card(
      title: 'Allergy / medical note',
      icon: Icons.health_and_safety_rounded,
      accent: has ? orange : green,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: has ? const Color(0xFFFFF3E3) : const Color(0xFFE5F5ED),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          has ? c.allergyNote.trim() : 'Nothing noted for this child.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: has ? const Color(0xFF9A6516) : green,
          ),
        ),
      ),
    );
  }

  Widget _buildParents(ChildInfo c) {
    // contacts मध्ये phone नसलेले पण नाव असलेले पण दाखवतो; पूर्ण रिकामे वगळतो.
    final contacts =
    c.contacts.where((p) => p.name.trim().isNotEmpty || p.phone.trim().isNotEmpty).toList();

    return _card(
      title: 'Parent / guardian',
      icon: Icons.family_restroom_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Parent name', c.parentName),
          _infoRow('Parent email', c.parentEmail),
          if (contacts.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Divider(height: 1, color: border),
            const SizedBox(height: 8),
            for (final p in contacts) _contactTile(p),
          ],
        ],
      ),
    );
  }

  Widget _contactTile(ParentContact p) {
    final hasPhone = p.phone.trim().isNotEmpty;
    final name = p.name.trim().isEmpty ? 'Contact' : p.name.trim();
    final sub = [
      if (p.relation.trim().isNotEmpty) p.relation.trim(),
      if (hasPhone) p.phone.trim(),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFFE4F3EF),
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: dark,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: muted),
                  ),
              ],
            ),
          ),
          if (hasPhone)
            InkWell(
              onTap: () => _call(p.phone),
              onLongPress: () async {
                await Clipboard.setData(ClipboardData(text: p.phone));
                if (mounted) _snack('Number copied: ${p.phone}');
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.call_rounded, size: 18, color: green),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickup(ChildInfo c) {
    return _card(
      title: 'Pickup note',
      icon: Icons.directions_walk_rounded,
      accent: const Color(0xFF7963C9),
      child: Text(
        c.pickupNote.trim(),
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.35,
          color: dark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // ATTENDANCE SUMMARY
  // ---------------------------------------------------------------
  Widget _buildAttendance() {
    return _card(
      title: 'Attendance · last $_summaryDays days',
      icon: Icons.fact_check_rounded,
      child: _attBody(),
    );
  }

  Widget _attBody() {
    if (_loadingAtt) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: primary),
          ),
        ),
      );
    }
    if (_attError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _attError!,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ),
          TextButton(onPressed: _loadAttendance, child: const Text('Retry')),
        ],
      );
    }

    final list = _recent;
    if (list.isEmpty) {
      return const Text(
        'No attendance marked yet.',
        style: TextStyle(fontSize: 12, color: muted),
      );
    }

    final p = list.where((a) => a.status == 'P').length;
    final a = list.where((a) => a.status == 'A').length;
    final l = list.where((a) => a.status == 'L').length;
    final marked = p + a + l;
    // Late मुलं वर्गात असतात, म्हणून Present मध्ये मोजतो (attendance screen प्रमाणे).
    final pct = marked == 0 ? 0 : (((p + l) / marked) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _statBox('Present', p, green, const Color(0xFFE5F5ED))),
            const SizedBox(width: 8),
            Expanded(child: _statBox('Absent', a, red, const Color(0xFFFFEFED))),
            const SizedBox(width: 8),
            Expanded(child: _statBox('Late', l, orange, const Color(0xFFFFF3E3))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'Attendance',
              style: TextStyle(
                fontSize: 11.5,
                color: muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 13,
                color: dark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5ECE9),
            valueColor: AlwaysStoppedAnimation<Color>(
              pct >= 75 ? green : (pct >= 50 ? orange : red),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Recent days',
          style: TextStyle(
            fontSize: 11.5,
            color: muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        for (final e in list.take(7)) _attRow(e),
      ],
    );
  }

  Widget _statBox(String label, int value, Color color, Color light) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: light,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attRow(_AttEntry e) {
    final Color color;
    final String label;
    switch (e.status) {
      case 'P':
        color = green;
        label = 'Present';
        break;
      case 'A':
        color = red;
        label = 'Absent';
        break;
      case 'L':
        color = orange;
        label = 'Late';
        break;
      default:
        color = muted;
        label = e.status.isEmpty ? '—' : e.status;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _shortDay(e.date),
              style: const TextStyle(
                fontSize: 12,
                color: dark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (e.status == 'A' && e.reason.trim().isNotEmpty)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  e.reason.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttEntry {
  _AttEntry(this.date, this.status, this.reason);
  final DateTime date;
  final String status; // 'P' / 'A' / 'L'
  final String reason;
}

/// मुलाचा गोल avatar: facePhoto (base64) असेल तर तो फोटो, नसेल तर नावाची
/// अक्षरे (initials). My Students list आणि Profile दोन्हीकडे हेच वापरतो.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.child,
    this.radius = 22,
    this.onDark = false,
  });

  final ChildInfo child;
  final double radius;

  /// true = गडद (gradient) background वर आहे, म्हणून पांढरी कडा.
  final bool onDark;

  static const Color _primary = Color(0xFF168C80);

  static String initials(String name) => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0])
      .take(2)
      .join()
      .toUpperCase();

  ImageProvider? _photo() {
    final data = child.facePhoto;
    if (data.isEmpty) return null;
    try {
      final comma = data.indexOf(',');
      final raw = comma < 0 ? data : data.substring(comma + 1);
      return MemoryImage(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo();
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: onDark ? Colors.white54 : const Color(0xFFE4F3EF),
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor:
        onDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE4F3EF),
        backgroundImage: photo,
        child: photo == null
            ? Text(
          initials(child.name),
          style: TextStyle(
            fontSize: radius * 0.62,
            fontWeight: FontWeight.w800,
            color: onDark ? Colors.white : _primary,
          ),
        )
            : null,
      ),
    );
  }
}