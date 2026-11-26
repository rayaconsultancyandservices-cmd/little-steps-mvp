import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/parent_widgets.dart';
import 'parent_home_screen.dart' show ParentColors;

/// TEST MODE: true असताना "Pay online" मध्ये कोणताही खरा UPI app उघडत नाही
/// आणि खरे पैसे जात नाहीत. "Simulate payment" बटण TEST UTR (TEST12345678 सारखा)
/// बनवतो; request तशीच Teacher/Admin ला verify साठी जाते.
/// प्रत्यक्ष शाळेत वापरण्यापूर्वी हे `false` करा.
const bool _kTestPaymentMode = true;

/// P5 · Fees  (School office / Teacher ने भरलेला खरा data — Firestore)
///
/// Features:
///  - Back arrow (same as Photos / Diary / Circulars)
///  - Hero card: पुढची unpaid fee (Due / Upcoming / Overdue), countdown,
///    "Pay online" + "How to pay"
///  - Summary: Total / Paid / Pending + progress bar + Overdue रक्कम
///    + "Under verification" रक्कम
///  - Fee list: All / Pending / Paid filter, status icon, due date,
///    Overdue / Verifying chip, tap-for-details
///  - UPI ने Online payment (UPI app उघडतो) + UTR टाकून school ला verify साठी पाठवणे
///  - NEW: UPI app मधून परत आल्यावर UTR box आपोआप focus, UTR paste, "I confirm" tick,
///    चुकीचा / duplicate UTR अडवणे, दुसऱ्या फोनवरून आधीच submit केलं असेल तर अडवणे
///  - NEW: "Online payment requests" यादी — tap करून details, चुकीचं request withdraw करणे,
///    "Show all"
///  - NEW: School ने UPI सेट केला नसेल तर "Pay online" ऐवजी स्पष्ट "pay at school" स्थिती
///  - NEW: खरा pull-to-refresh (server वरून), load error चा स्पष्ट संदेश
///  - Receipts list with view / copy (+ receipt number)
///  - Copy full fee statement
class ParentFeesScreen extends StatefulWidget {
  const ParentFeesScreen({super.key, this.onBack});

  /// Back arrow action. By default it goes back to Home
  /// (the shell handles the system back for the tabs).
  final VoidCallback? onBack;

  @override
  State<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

/// Parent ने "I have paid" म्हणून पाठवलेली payment request
/// (Firestore: students/{studentId}/payments/{id}).
class _PayClaim {
  const _PayClaim({
    required this.id,
    required this.feeId,
    required this.title,
    required this.amount,
    required this.utr,
    required this.status,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final String feeId;
  final String title;
  final int amount;
  final String utr;

  /// submitted | verified | rejected
  final String status;
  final DateTime createdAt;

  /// Teacher ने reject केल्यावर लिहिलेलं कारण (असल्यास)
  final String note;

  factory _PayClaim.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    final ts = x['createdAt'];
    final amt = x['amount'];
    return _PayClaim(
      id: d.id,
      feeId: (x['feeId'] ?? '').toString(),
      title: (x['title'] ?? '').toString(),
      amount: amt is num ? amt.toInt() : 0,
      utr: (x['utr'] ?? '').toString(),
      status: (x['status'] ?? 'submitted').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      note: (x['note'] ?? '').toString(),
    );
  }
}

/// Fee schedule चा filter.
enum _FeeFilter { all, pending, paid }

/// 3:07 PM
String _time(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

class _ParentFeesScreenState extends State<ParentFeesScreen> {
  // ---------- colours for status ----------
  static const _paidFg = Color(0xFF2F8877);
  static const _paidBg = Color(0xFFDDF2EC);
  static const _dueFg = Color(0xFFD9564F);
  static const _dueBg = Color(0xFFFFE7E5);
  static const _upFg = Color(0xFF6B8399);
  static const _upBg = Color(0xFFEFF1F3);
  static const _waitFg = Color(0xFFB7791F);
  static const _waitBg = Color(0xFFFFF4DC);

  // ---------- online payment data ----------
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _classSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paySub;
  String _studentId = '';
  String _classId = '';

  /// School ने class document मध्ये ठेवलेला UPI ID / नाव (नसेल तर online payment बंद).
  String _upiId = '';
  String _upiName = '';
  List<_PayClaim> _claims = [];

  /// Payment requests वाचता आल्या नाहीत तर parent ला दाखवायचा संदेश.
  String? _payError;

  // ---------- UI state ----------
  _FeeFilter _filter = _FeeFilter.all;
  bool _showAllClaims = false;

  @override
  void initState() {
    super.initState();
    _attach(AppState.instance);
  }

  @override
  void dispose() {
    _classSub?.cancel();
    _paySub?.cancel();
    super.dispose();
  }

  String _friendlyPayError(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'Online payment status is not available right now. '
          'You can still pay at the school office.';
    }
    return 'Could not load your online payment requests. '
        'Please check your internet connection.';
  }

  /// Class (UPI ID) आणि या मुलाच्या payment requests ऐकायला सुरू करतो.
  void _attach(AppState s) {
    final sid = s.child.id;
    final cid = s.classId;
    if (sid == _studentId && cid == _classId) return;
    _studentId = sid;
    _classId = cid;

    _classSub?.cancel();
    _paySub?.cancel();
    _classSub = null;
    _paySub = null;
    _claims = [];
    _payError = null;
    _showAllClaims = false;

    final db = FirebaseFirestore.instance;
    if (cid.isNotEmpty) {
      _classSub = db.collection('classes').doc(cid).snapshots().listen(
            (d) {
          final c = d.data();
          if (!mounted) return;
          setState(() {
            _upiId = ((c?['upiId']) ?? '').toString().trim();
            _upiName = ((c?['upiName']) ?? '').toString().trim();
          });
        },
        onError: (Object _) {},
      );
    }
    if (sid.isNotEmpty) {
      _paySub = db
          .collection('students')
          .doc(sid)
          .collection('payments')
          .snapshots()
          .listen(
            (snap) {
          if (!mounted) return;
          final list = [for (final d in snap.docs) _PayClaim.fromDoc(d)]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          setState(() {
            _claims = list;
            _payError = null;
          });
        },
        // आधी error गिळला जात होता; आता parent ला स्पष्ट संदेश दिसतो.
        onError: (Object e) {
          if (!mounted) return;
          setState(() => _payError = _friendlyPayError(e));
        },
      );
    }
  }

  // ---------- helpers ----------
  String _yearLabel() {
    final now = DateTime.now();
    return now.month >= 4
        ? '${now.year}-${(now.year + 1) % 100}'
        : '${now.year - 1}-${now.year % 100}';
  }

  int _daysLeft(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(d.year, d.month, d.day).difference(today).inDays;
  }

  /// Due date उलटून गेली आणि fee अजून paid नाही.
  bool _isOverdue(FeeItem f) =>
      f.status != FeeStatus.paid &&
          f.dueDate != null &&
          _daysLeft(f.dueDate!) < 0;

  String _statusText(FeeItem f) {
    if (f.status == FeeStatus.paid) return 'Paid';
    if (_isOverdue(f)) return 'Overdue';
    return f.status == FeeStatus.due ? 'Due' : 'Upcoming';
  }

  /// सर्व unpaid fees: आधी Due / Overdue, मग जवळची due date.
  List<FeeItem> _unpaid(AppState s) {
    final list = s.fees.where((f) => f.status != FeeStatus.paid).toList();
    int rank(FeeItem f) =>
        (f.status == FeeStatus.due || _isOverdue(f)) ? 0 : 1;
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final da = a.dueDate ?? DateTime(2100);
      final db = b.dueDate ?? DateTime(2100);
      return da.compareTo(db);
    });
    return list;
  }

  /// Hero साठी: पहिली unpaid fee जिची payment verify व्हायची वाट बघत नाहीये.
  /// (आधी पहिली unpaid fee verify होत असेल तर बाकीच्या fees pay करता येत नव्हत्या.)
  FeeItem? _payable(List<FeeItem> unpaid) {
    for (final f in unpaid) {
      if (_activeClaim(f) == null) return f;
    }
    return null;
  }

  /// Verify व्हायची वाट बघणाऱ्या सर्व fees ची एकूण रक्कम.
  int _verifyingAmount(List<FeeItem> unpaid) => unpaid
      .where((f) => _activeClaim(f) != null)
      .fold<int>(0, (a, f) => a + f.amount);

  FeeReceipt? _receiptFor(AppState s, FeeItem f) {
    // खरा link: receipt मध्ये feeId असतो. जुन्या receipts साठी title वर fallback.
    for (final r in s.receipts) {
      if (r.feeId.isNotEmpty && r.feeId == f.id) return r;
    }
    for (final r in s.receipts) {
      if (r.feeId.isEmpty &&
          r.title.isNotEmpty &&
          f.title.toLowerCase() == r.title.toLowerCase()) {
        return r;
      }
    }
    return null;
  }

  /// या fee साठी verify व्हायची वाट बघणारी payment request.
  _PayClaim? _activeClaim(FeeItem f) {
    if (f.id.isEmpty || f.status == FeeStatus.paid) return null;
    for (final c in _claims) {
      if (c.feeId == f.id && c.status == 'submitted') return c;
    }
    return null;
  }

  /// या fee ची सर्वात ताजी request reject झाली असेल तरच ती (पुन्हा pay करताना
  /// कारण दाखवण्यासाठी). नंतर नवीन request आली असेल तर null.
  _PayClaim? _lastRejected(FeeItem f) {
    if (f.id.isEmpty) return null;
    for (final c in _claims) {
      if (c.feeId == f.id) return c.status == 'rejected' ? c : null;
    }
    return null;
  }

  /// `name@bank` format चा UPI ID असेल तरच online payment चालू.
  String _validUpi(String v) =>
      RegExp(r'^[A-Za-z0-9.\-_]{2,}@[A-Za-z]{2,}$').hasMatch(v) ? v : '';

  /// School ने वैध UPI ID सेट केला आहे का.
  bool get _upiReady => _kTestPaymentMode || _validUpi(_upiId).isNotEmpty;

  ({IconData icon, Color fg, Color bg, String chip}) _claimTone(String status) {
    switch (status) {
      case 'verified':
        return (
        icon: Icons.verified_rounded,
        fg: _paidFg,
        bg: _paidBg,
        chip: 'Verified'
        );
      case 'rejected':
        return (
        icon: Icons.cancel_rounded,
        fg: _dueFg,
        bg: _dueBg,
        chip: 'Rejected'
        );
      default:
        return (
        icon: Icons.hourglass_top_rounded,
        fg: _waitFg,
        bg: _waitBg,
        chip: 'Verifying'
        );
    }
  }

  /// खरा pull-to-refresh: payment requests आणि UPI माहिती server वरून पुन्हा घेतो.
  /// (Fees / receipts आधीच live stream ने येतात.)
  Future<void> _refresh() async {
    final sid = _studentId;
    final cid = _classId;
    if (sid.isEmpty) return;
    final db = FirebaseFirestore.instance;
    try {
      final snap = await db
          .collection('students')
          .doc(sid)
          .collection('payments')
          .get(const GetOptions(source: Source.server));
      if (cid.isNotEmpty) {
        final c = await db
            .collection('classes')
            .doc(cid)
            .get(const GetOptions(source: Source.server));
        final data = c.data();
        if (mounted) {
          _upiId = ((data?['upiId']) ?? '').toString().trim();
          _upiName = ((data?['upiName']) ?? '').toString().trim();
        }
      }
      if (!mounted) return;
      setState(() {
        _claims = [for (final d in snap.docs) _PayClaim.fromDoc(d)]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _payError = null;
      });
    } catch (_) {
      if (!mounted) return;
      showSnack(context, 'Could not refresh. Please check your internet.');
    }
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;

        // मूल / class बदलला तर listeners पुन्हा जोडतो.
        if (s.child.id != _studentId || s.classId != _classId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _attach(AppState.instance);
          });
        }

        final unpaid = _unpaid(s);
        final payable = _payable(unpaid);
        final verifyingAmt = _verifyingAmount(unpaid);

        final total = s.fees.fold<int>(0, (a, f) => a + f.amount);
        final paid = s.fees
            .where((f) => f.status == FeeStatus.paid)
            .fold<int>(0, (a, f) => a + f.amount);
        final pending = total - paid;
        final overdueAmt = unpaid
            .where(_isOverdue)
            .fold<int>(0, (a, f) => a + f.amount);

        return Column(
          children: [
            _header(context, s, paid, pending, total),
            Expanded(
              child: RefreshIndicator(
                color: ParentColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _hero(context, s, unpaid, payable, pending, verifyingAmt),
                    const SizedBox(height: 14),
                    _summary(total, paid, pending, overdueAmt, verifyingAmt),
                    const SizedBox(height: 16),
                    _sectionTitle('Fee schedule', 'Year ${_yearLabel()}'),
                    if (s.fees.length >= 3) _filterChips(s),
                    _feeList(context, s),
                    if (_payError != null) ...[
                      const SizedBox(height: 14),
                      _noticeCard(_payError!),
                    ],
                    if (_claims.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _sectionTitle(
                          'Online payment requests', '${_claims.length}'),
                      _claimList(context),
                    ],
                    const SizedBox(height: 18),
                    _sectionTitle('Receipts',
                        s.receipts.isEmpty ? null : '${s.receipts.length}'),
                    _receiptList(context, s),
                    const SizedBox(height: 14),
                    _note(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- header (back arrow + title + copy) ----------
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

  Widget _header(
      BuildContext context, AppState s, int paid, int pending, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          _roundBtn(
            Icons.arrow_back_ios_new_rounded,
            widget.onBack ?? () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fees',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.child.name} · ${s.child.className}',
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
                () => _copyStatement(context, s, paid, pending, total),
            tooltip: 'Copy fee statement',
          ),
          const SizedBox(width: 8),
          _roundBtn(
            Icons.share_rounded,
                () => _shareStatement(context, s, paid, pending, total),
            tooltip: 'Share fee statement on WhatsApp',
          ),
        ],
      ),
    );
  }

  Future<void> _copyStatement(BuildContext context, AppState s, int paid,
      int pending, int total) async {
    await Clipboard.setData(
        ClipboardData(text: _statementText(s, paid, pending, total)));
    if (context.mounted) showSnack(context, 'Fee statement copied');
  }

  Future<void> _shareStatement(BuildContext context, AppState s, int paid,
      int pending, int total) async {
    await _shareWhatsApp(
        context, _statementText(s, paid, pending, total));
  }

  /// Text WhatsApp मध्ये share करतो. WhatsApp उघडलं नाही तर text copy होतो.
  Future<void> _shareWhatsApp(BuildContext context, String text) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (ok) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showSnack(context, 'WhatsApp could not be opened. Text copied instead.');
    }
  }

  String _statementText(AppState s, int paid, int pending, int total) {
    final verifying = _verifyingAmount(_unpaid(s));
    final b = StringBuffer()
      ..writeln('Fee statement · ${_yearLabel()}');
    if (s.schoolName.isNotEmpty) b.writeln('School: ${s.schoolName}');
    b
      ..writeln('Student: ${s.child.name} (${s.child.className})')
      ..writeln();
    for (final f in s.fees) {
      final d = f.dueDate != null && f.status != FeeStatus.paid
          ? ' (by ${AppState.shortDate(f.dueDate!)})'
          : '';
      final st = _activeClaim(f) != null ? 'Verifying' : _statusText(f);
      b.writeln('${f.title}: ${rupees(f.amount)} - $st$d');
    }
    b
      ..writeln()
      ..writeln('Total: ${rupees(total)}')
      ..writeln('Paid: ${rupees(paid)}')
      ..writeln('Pending: ${rupees(pending)}');
    if (verifying > 0) {
      b.writeln('Under verification: ${rupees(verifying)}');
    }
    b
      ..writeln()
      ..writeln('As on ${AppState.shortDate(DateTime.now())}, '
          '${_time(DateTime.now())}');
    return b.toString();
  }

  // ---------- hero card ----------
  Widget _hero(BuildContext context, AppState s, List<FeeItem> unpaid,
      FeeItem? payable, int pending, int verifyingAmt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ParentColors.primary, ParentColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332B8FDB),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      // fees नाहीत -> empty; सर्व paid -> paid; सर्व unpaid fees verify होत आहेत
      // -> verifying; नाहीतर pay करता येणारी पुढची fee.
      child: s.fees.isEmpty
          ? _heroEmpty()
          : unpaid.isEmpty
          ? _heroPaid()
          : payable == null
          ? _heroVerifying(verifyingAmt)
          : _heroDue(context, s, payable, pending),
    );
  }

  Widget _heroMessage(IconData icon, String title, String sub) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0x33FFFFFF),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sub,
                  style:
                  const TextStyle(color: Color(0xFFEAF5FD), fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroPaid() => _heroMessage(Icons.check_circle_rounded,
      'All fees are paid', 'Nothing pending right now. Thank you!');

  Widget _heroEmpty() => _heroMessage(Icons.receipt_long_rounded,
      'No fees added yet', 'The school office will add the fees here.');

  Widget _heroVerifying(int amount) => _heroMessage(
      Icons.hourglass_top_rounded,
      'Payment submitted',
      '${rupees(amount)} is waiting for the school to verify.');

  Widget _heroDue(
      BuildContext context, AppState s, FeeItem due, int pending) {
    final days = due.dueDate == null ? null : _daysLeft(due.dueDate!);
    final overdue = days != null && days < 0;
    final countdown = days == null
        ? null
        : overdue
        ? 'Overdue by ${-days} day${-days == 1 ? '' : 's'}'
        : days == 0
        ? 'Due today'
        : 'Due in $days day${days == 1 ? '' : 's'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                due.dueDate == null
                    ? 'Amount due'
                    : 'Due by ${AppState.shortDate(due.dueDate!)}',
                style: const TextStyle(color: Color(0xFFEAF5FD), fontSize: 11.5),
              ),
            ),
            if (countdown != null)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: overdue ? ParentColors.danger : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  countdown,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          rupees(due.amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${due.title} · ${s.child.name}',
          style: const TextStyle(color: Color(0xFFEAF5FD), fontSize: 11.5),
        ),
        if (pending > due.amount) ...[
          const SizedBox(height: 2),
          Text(
            'Total pending: ${rupees(pending)}',
            style: const TextStyle(
                color: Color(0xFFEAF5FD),
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 12),
        _heroActions(context, s, due),
      ],
    );
  }

  /// "Pay online" + "How to pay" (किंवा payment verify होत असेल तर तो संदेश).
  /// School ने UPI सेट केला नसेल तर "Pay online" दाखवत नाही (dead-end टाळण्यासाठी).
  Widget _heroActions(BuildContext context, AppState s, FeeItem due) {
    final claim = _activeClaim(due);
    if (claim != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x40FFFFFF)),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Payment submitted · waiting for the school to verify',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    if (!_upiReady) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _howToPay(context, s, due),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text('How to pay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ParentColors.primary,
                elevation: 0,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Online payment is not enabled for this class yet. '
                'Please pay at the school office.',
            style: TextStyle(color: Color(0xFFEAF5FD), fontSize: 11, height: 1.4),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: ElevatedButton.icon(
            onPressed: () => _openPay(context, s, due),
            icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
            label: const Text('Pay online'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: ParentColors.primary,
              elevation: 0,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Material(
            color: const Color(0x26FFFFFF),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _howToPay(context, s, due),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x40FFFFFF)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payments_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('How to pay',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- summary ----------
  Widget _summary(
      int total, int paid, int pending, int overdueAmt, int verifyingAmt) {
    final progress = total == 0 ? 0.0 : paid / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            children: [
              _stat('Total', rupees(total), ParentColors.dark),
              _divider(),
              _stat('Paid', rupees(paid), _paidFg),
              _divider(),
              _stat('Pending', rupees(pending),
                  pending == 0 ? _paidFg : _dueFg),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: ParentColors.tintStrong,
              valueColor: const AlwaysStoppedAnimation(ParentColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${(progress * 100).round()}% of the yearly fees paid',
              style: const TextStyle(
                  fontSize: 11,
                  color: ParentColors.muted,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (verifyingAmt > 0) ...[
            const SizedBox(height: 10),
            _summaryNote(
              Icons.hourglass_top_rounded,
              '${rupees(verifyingAmt)} is under verification by the school.',
              _waitFg,
              _waitBg,
            ),
          ],
          if (overdueAmt > 0) ...[
            const SizedBox(height: 10),
            _summaryNote(
              Icons.warning_amber_rounded,
              '${rupees(overdueAmt)} is overdue. Please pay soon.',
              _dueFg,
              _dueBg,
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryNote(IconData icon, String text, Color fg, Color bg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: ParentColors.muted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: ParentColors.border);

  // ---------- fee list ----------
  List<FeeItem> _filtered(AppState s) {
    switch (_filter) {
      case _FeeFilter.pending:
        return s.fees.where((f) => f.status != FeeStatus.paid).toList();
      case _FeeFilter.paid:
        return s.fees.where((f) => f.status == FeeStatus.paid).toList();
      case _FeeFilter.all:
        return s.fees;
    }
  }

  /// All / Pending / Paid (fees ३ किंवा जास्त असतील तेव्हाच दिसतो).
  Widget _filterChips(AppState s) {
    final pendingN = s.fees.where((f) => f.status != FeeStatus.paid).length;
    final paidN = s.fees.length - pendingN;

    Widget chip(_FeeFilter f, String label) {
      final on = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: on ? ParentColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: on ? ParentColors.primary : ParentColors.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : ParentColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(_FeeFilter.all, 'All ${s.fees.length}'),
            chip(_FeeFilter.pending, 'Pending $pendingN'),
            chip(_FeeFilter.paid, 'Paid $paidN'),
          ],
        ),
      ),
    );
  }

  Widget _feeList(BuildContext context, AppState s) {
    // बदल: fee नसेल तर रिकामा card न दाखवता स्पष्ट संदेश.
    if (s.fees.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: _cardDeco(),
        child: const Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 34, color: ParentColors.muted),
            SizedBox(height: 8),
            Text('No fees added yet',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark)),
            SizedBox(height: 2),
            Text('Fees added by the school office will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: ParentColors.muted)),
          ],
        ),
      );
    }

    final list = _filtered(s);
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: _cardDeco(),
        child: Text(
          _filter == _FeeFilter.paid
              ? 'No fee has been paid yet.'
              : 'Nothing pending. All fees are paid.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ParentColors.muted),
        ),
      );
    }

    return Container(
      decoration: _cardDeco(),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            _feeRow(context, s, list[i]),
            if (i != list.length - 1)
              const Divider(height: 1, indent: 64, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _feeRow(BuildContext context, AppState s, FeeItem f) {
    final claim = _activeClaim(f);
    final rejected = claim == null ? _lastRejected(f) : null;
    final overdue = _isOverdue(f);

    final IconData icon;
    final Color fg;
    final Color bg;
    final String chip;
    if (f.status == FeeStatus.paid) {
      icon = Icons.check_circle_rounded;
      fg = _paidFg;
      bg = _paidBg;
      chip = 'Paid';
    } else if (claim != null) {
      icon = Icons.hourglass_top_rounded;
      fg = _waitFg;
      bg = _waitBg;
      chip = 'Verifying';
    } else if (overdue) {
      icon = Icons.error_outline_rounded;
      fg = _dueFg;
      bg = _dueBg;
      chip = 'Overdue';
    } else if (f.status == FeeStatus.due) {
      icon = Icons.error_outline_rounded;
      fg = _dueFg;
      bg = _dueBg;
      chip = 'Due';
    } else {
      icon = Icons.schedule_rounded;
      fg = _upFg;
      bg = _upBg;
      chip = 'Upcoming';
    }

    final receipt = _receiptFor(s, f);
    String sub;
    if (f.status == FeeStatus.paid) {
      sub = receipt == null
          ? rupees(f.amount)
          : '${rupees(f.amount)} · Paid ${AppState.shortDate(receipt.date)}';
    } else if (f.dueDate == null) {
      sub = rupees(f.amount);
    } else if (overdue) {
      final d = -_daysLeft(f.dueDate!);
      sub = '${rupees(f.amount)} · Overdue by $d day${d == 1 ? '' : 's'}';
    } else {
      sub = '${rupees(f.amount)} · Due by ${AppState.shortDate(f.dueDate!)}';
    }
    if (rejected != null && f.status != FeeStatus.paid) {
      sub = '$sub · Payment not verified';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _feeDetail(context, s, f, receipt),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.title,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.dark)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: (overdue || rejected != null) && claim == null
                              ? _dueFg
                              : ParentColors.muted,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            StatusChip(chip, bg: bg, fg: fg),
          ],
        ),
      ),
    );
  }

  void _feeDetail(
      BuildContext context, AppState s, FeeItem f, FeeReceipt? receipt) {
    final statusText = _statusText(f);
    final claim = _activeClaim(f);
    final rejected = claim == null ? _lastRejected(f) : null;
    final overdue = _isOverdue(f);
    final color = f.status == FeeStatus.paid
        ? _paidFg
        : (f.status == FeeStatus.due || overdue)
        ? _dueFg
        : _upFg;
    final canPay = f.status != FeeStatus.paid && claim == null && _upiReady;

    final String footerText;
    if (f.status == FeeStatus.paid) {
      footerText = '';
    } else if (claim != null) {
      footerText = 'Your payment was submitted. The school will verify it and '
          'mark this fee as Paid.';
    } else if (!_upiReady) {
      footerText = 'Online payment is not enabled for this class yet. '
          'Please pay at the school office (Cash / UPI).';
    } else if (rejected != null) {
      footerText = 'Your last payment request could not be verified. '
          'You can pay again, or visit the school office.';
    } else {
      footerText = 'You can pay online by UPI, or at the school office.';
    }

    _sheet(
      context,
      title: f.title,
      amount: rupees(f.amount),
      amountColor: color,
      rows: [
        _row('Student', s.child.name),
        _row('Class', s.child.className),
        _row('Status', claim != null ? 'Verifying payment' : statusText),
        if (f.dueDate != null && f.status != FeeStatus.paid)
          _row('Due date', AppState.dateLabel(f.dueDate!)),
        if (overdue)
          _row('Overdue by',
              '${-_daysLeft(f.dueDate!)} day${-_daysLeft(f.dueDate!) == 1 ? '' : 's'}'),
        if (claim != null) _row('UPI reference', claim.utr),
        if (rejected != null) _row('Last request', 'Not verified'),
        if (rejected != null && rejected.note.isNotEmpty)
          _row('School note', rejected.note),
        if (receipt != null) ...[
          _row('Paid on', AppState.dateLabel(receipt.date)),
          _row('Mode', receipt.mode),
        ],
      ],
      copyText: '${f.title} · ${rupees(f.amount)} · $statusText\n'
          'Student: ${s.child.name} (${s.child.className})',
      footer: footerText.isEmpty
          ? null
          : Text(
        footerText,
        style: const TextStyle(
            fontSize: 12, color: ParentColors.muted, height: 1.5),
      ),
      extraBuilder: canPay
          ? (ctx) => _payButton(() {
        Navigator.pop(ctx);
        _openPay(context, s, f);
      })
          : null,
    );
  }

  /// Sheet मधला मोठा "Pay online" button.
  Widget _payButton(VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
        label: const Text('Pay online (UPI)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ParentColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(46),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  // ---------- online payment requests ----------
  Widget _noticeCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _waitBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: _waitFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: _waitFg,
                    height: 1.4,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _claimList(BuildContext context) {
    final more = _claims.length > 5;
    final list = _showAllClaims ? _claims : _claims.take(5).toList();
    return Container(
      decoration: _cardDeco(),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            _claimRow(context, list[i]),
            if (i != list.length - 1)
              const Divider(height: 1, indent: 64, color: AppColors.border),
          ],
          if (more) ...[
            const Divider(height: 1, color: AppColors.border),
            InkWell(
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(18)),
              onTap: () => setState(() => _showAllClaims = !_showAllClaims),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Center(
                  child: Text(
                    _showAllClaims ? 'Show less' : 'Show all (${_claims.length})',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ParentColors.primary),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _claimRow(BuildContext context, _PayClaim c) {
    final t = _claimTone(c.status);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _claimDetail(context, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(t.icon, size: 21, color: t.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c.title} · ${rupees(c.amount)}',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.dark)),
                  const SizedBox(height: 2),
                  Text('UPI · ${c.utr} · ${AppState.shortDate(c.createdAt)}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: ParentColors.muted,
                          fontWeight: FontWeight.w500)),
                  if (c.status == 'rejected' && c.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('School: ${c.note}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: _dueFg,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            StatusChip(t.chip, bg: t.bg, fg: t.fg),
          ],
        ),
      ),
    );
  }

  /// Payment request ची details; verify होण्याआधी चुकलं असेल तर withdraw करता येतं.
  void _claimDetail(BuildContext context, _PayClaim c) {
    final t = _claimTone(c.status);
    final submitted = c.status == 'submitted';
    final String footerText;
    switch (c.status) {
      case 'verified':
        footerText = 'The school verified this payment.';
        break;
      case 'rejected':
        footerText = 'The school could not verify this payment. '
            'You can pay again from the fee, or visit the school office.';
        break;
      default:
        footerText = 'Waiting for the school to verify. If you entered a wrong '
            'reference number, withdraw this request and submit again.';
    }

    _sheet(
      context,
      title: 'Payment request',
      amount: rupees(c.amount),
      amountColor: t.fg,
      badge: StatusChip(t.chip, bg: t.bg, fg: t.fg),
      rows: [
        _row('Fee', c.title),
        _row('Mode', 'UPI'),
        _row('UPI reference', c.utr),
        _row('Submitted',
            '${AppState.dateLabel(c.createdAt)}, ${_time(c.createdAt)}'),
        if (c.status == 'rejected' && c.note.isNotEmpty)
          _row('School note', c.note),
      ],
      copyText: 'Payment request\n'
          'Fee: ${c.title}\n'
          'Amount: ${rupees(c.amount)}\n'
          'UPI reference: ${c.utr}\n'
          'Status: ${t.chip}',
      footer: Text(footerText,
          style: const TextStyle(
              fontSize: 12, color: ParentColors.muted, height: 1.5)),
      extraBuilder: submitted
          ? (ctx) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            _confirmWithdraw(context, c);
          },
          icon: const Icon(Icons.undo_rounded, size: 18),
          label: const Text('Withdraw request'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _dueFg,
            side: const BorderSide(color: _dueFg),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      )
          : null,
    );
  }

  Future<void> _confirmWithdraw(BuildContext context, _PayClaim c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw this request?'),
        content: Text(
          'Your request for ${c.title} (${rupees(c.amount)}, ref ${c.utr}) '
              'will be removed. If you have already paid, please keep the '
              'payment proof and submit the correct reference.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _dueFg),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await _withdrawClaim(c);
    if (!context.mounted) return;
    showSnack(context, err ?? 'Payment request withdrawn');
  }

  /// Verify होण्याआधीची request काढतो. यशस्वी झाल्यास null, नाहीतर error text.
  Future<String?> _withdrawClaim(_PayClaim c) async {
    if (_studentId.isEmpty) return 'Could not withdraw. Please try again.';
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(_studentId)
          .collection('payments')
          .doc(c.id)
          .delete();
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'Could not withdraw. The school may have already verified it.';
      }
      return e.message ?? 'Could not withdraw. Please try again.';
    } catch (_) {
      return 'Could not withdraw. Please check your internet and try again.';
    }
  }

  // ---------- receipts ----------
  /// Receipt चा लहान क्रमांक (document id च्या शेवटच्या ६ अक्षरांवरून).
  String _receiptNo(FeeReceipt r) {
    if (r.id.isEmpty) return '';
    final tail = r.id.length > 6 ? r.id.substring(r.id.length - 6) : r.id;
    return 'LS-${tail.toUpperCase()}';
  }

  Widget _receiptList(BuildContext context, AppState s) {
    if (s.receipts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        decoration: _cardDeco(),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 34, color: ParentColors.muted),
            SizedBox(height: 8),
            Text('No receipts yet',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark)),
            SizedBox(height: 2),
            Text('Receipts appear here once a payment is recorded.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: ParentColors.muted)),
          ],
        ),
      );
    }

    return Container(
      decoration: _cardDeco(),
      child: Column(
        children: [
          for (var i = 0; i < s.receipts.length; i++) ...[
            _receiptRow(context, s, s.receipts[i]),
            if (i != s.receipts.length - 1)
              const Divider(height: 1, indent: 64, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _receiptRow(BuildContext context, AppState s, FeeReceipt r) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _receipt(context, s, r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ParentColors.tintStrong,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 20, color: ParentColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.title} receipt',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.dark)),
                  const SizedBox(height: 2),
                  Text('${AppState.shortDate(r.date)} · ${r.mode}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: ParentColors.muted,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(rupees(r.amount),
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: ParentColors.dark)),
                const SizedBox(height: 2),
                const Text('View',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ParentColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _receipt(BuildContext context, AppState s, FeeReceipt r) {
    final no = _receiptNo(r);
    _sheet(
      context,
      title: 'Fee receipt',
      amount: rupees(r.amount),
      amountColor: _paidFg,
      badge: const StatusChip('Paid', bg: _paidBg, fg: _paidFg),
      rows: [
        if (no.isNotEmpty) _row('Receipt no.', no),
        if (s.schoolName.isNotEmpty) _row('School', s.schoolName),
        _row('Student', s.child.name),
        _row('Class', s.child.className),
        _row('Fee', r.title),
        _row('Paid on', AppState.dateLabel(r.date)),
        _row('Mode', r.mode),
      ],
      canShare: true,
      copyText: 'Fee receipt\n'
          '${no.isEmpty ? '' : 'Receipt no.: $no\n'}'
          '${s.schoolName.isEmpty ? '' : 'School: ${s.schoolName}\n'}'
          'Student: ${s.child.name}\n'
          'Class: ${s.child.className}\n'
          'Fee: ${r.title}\n'
          'Amount: ${rupees(r.amount)}\n'
          'Paid on: ${AppState.shortDate(r.date)}\n'
          'Mode: ${r.mode}',
    );
  }

  // ---------- how to pay ----------
  void _howToPay(BuildContext context, AppState s, FeeItem due) {
    final claim = _activeClaim(due);
    _sheet(
      context,
      title: 'How to pay',
      amount: rupees(due.amount),
      amountColor: _dueFg,
      rows: [
        _row('Fee', due.title),
        _row('Student', s.child.name),
        if (due.dueDate != null)
          _row('Last date', AppState.dateLabel(due.dueDate!)),
        _row('Online',
            _upiReady ? 'UPI (Pay online button)' : 'Not enabled yet'),
        _row('Pay at', 'School office'),
        _row('Accepted', 'Cash / UPI'),
      ],
      copyText: '${due.title} · ${rupees(due.amount)}\n'
          'Student: ${s.child.name} (${s.child.className})',
      footer: Text(
        _upiReady
            ? 'Pay online by UPI and enter the UPI reference number — the '
            'school will verify it. Or visit the office with the child\'s '
            'name.'
            : 'Please visit the school office with the child\'s name and pay '
            'by cash or UPI. The office will record the payment and your '
            'receipt will appear here.',
        style: const TextStyle(
            fontSize: 12, color: ParentColors.muted, height: 1.5),
      ),
      extraBuilder: claim == null && _upiReady
          ? (ctx) => _payButton(() {
        Navigator.pop(ctx);
        _openPay(context, s, due);
      })
          : null,
    );
  }

  // ---------- online payment (UPI) ----------
  void _openPay(BuildContext context, AppState s, FeeItem f) {
    if (!_upiReady) {
      showSnack(context,
          'Online payment is not enabled yet. Please pay at the school office.');
      return;
    }
    if (_activeClaim(f) != null) {
      showSnack(context,
          'Payment already submitted. Waiting for the school to verify.');
      return;
    }
    final rejected = _lastRejected(f);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PaySheet(
        fee: f,
        studentName: s.child.name,
        className: s.child.className,
        upiId: _validUpi(_upiId),
        upiName: _upiName.isNotEmpty
            ? _upiName
            : (s.schoolName.isNotEmpty ? s.schoolName : 'School'),
        rejectedNote: rejected == null
            ? null
            : (rejected.note.isEmpty
            ? 'Your last payment request could not be verified.'
            : 'Last request not verified: ${rejected.note}'),
        onSubmit: (utr) => _submitClaim(s, f, utr),
        onDone: () {
          if (context.mounted) {
            showSnack(
                context,
                _kTestPaymentMode
                    ? 'TEST payment submitted. Teacher / Admin can now verify it.'
                    : 'Submitted. The school will verify and mark it as Paid.');
          }
        },
      ),
    );
  }

  /// "I have paid" → Firestore मध्ये payment request. यशस्वी झाल्यास null.
  ///
  /// Submit आधीचे तपास:
  ///  1. fee मधल्या मध्ये school ने Paid केली का (live data).
  ///  2. हाच UTR आधी (rejected नसलेल्या) request मध्ये वापरला आहे का.
  ///  3. दुसऱ्या फोनवरून / double-tap ने या fee ची request आधीच गेली आहे का (server).
  Future<String?> _submitClaim(AppState s, FeeItem f, String utr) async {
    // 1. Fee आता Paid झाली असेल तर नवीन request नको.
    for (final x in s.fees) {
      if (x.id == f.id && x.status == FeeStatus.paid) {
        return 'This fee is already marked as Paid. No payment is needed.';
      }
    }
    // 2. Duplicate UTR.
    for (final c in _claims) {
      if (c.utr == utr && c.status != 'rejected') {
        return 'This UPI reference was already submitted'
            '${c.title.isEmpty ? '' : ' for ${c.title}'}.';
      }
    }

    try {
      final col = FirebaseFirestore.instance
          .collection('students')
          .doc(s.child.id)
          .collection('payments');

      // 3. Server वर या fee ची "submitted" request आहे का.
      if (f.id.isNotEmpty) {
        final dup = await col
            .where('feeId', isEqualTo: f.id)
            .where('status', isEqualTo: 'submitted')
            .limit(1)
            .get();
        if (dup.docs.isNotEmpty) {
          return 'A payment request for this fee is already waiting for the '
              'school to verify.';
        }
      }

      await col.add({
        'studentId': s.child.id,
        'classId': s.classId,
        'studentName': s.child.name,
        'feeId': f.id,
        'title': f.title,
        'amount': f.amount,
        'utr': utr,
        'method': 'UPI',
        'status': 'submitted',
        'createdAt': Timestamp.now(),
      });
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'Online payment requests are not enabled by the school yet. '
            'Please pay at the school office.';
      }
      if (e.code == 'unavailable') {
        return 'No internet connection. Please try again.';
      }
      return e.message ?? 'Could not submit. Please try again.';
    } catch (_) {
      return 'Could not submit. Please check your internet and try again.';
    }
  }

  // ---------- shared bottom sheet ----------
  void _sheet(
      BuildContext context, {
        required String title,
        required String amount,
        required Color amountColor,
        required List<Widget> rows,
        required String copyText,
        Widget? badge,
        Widget? footer,
        Widget Function(BuildContext ctx)? extraBuilder,
        bool canShare = false,
      }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: ParentColors.dark)),
                  ),
                  if (badge != null) badge,
                ],
              ),
              const SizedBox(height: 6),
              Text(amount,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: amountColor)),
              const SizedBox(height: 14),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: rows),
              ),
              if (footer != null) ...[
                const SizedBox(height: 12),
                footer,
              ],
              if (extraBuilder != null) ...[
                const SizedBox(height: 14),
                extraBuilder(ctx),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: copyText));
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          showSnack(context, 'Copied');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ParentColors.primary,
                        side: const BorderSide(color: ParentColors.border),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle:
                        const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: extraBuilder == null
                            ? ParentColors.primary
                            : ParentColors.tint,
                        foregroundColor: extraBuilder == null
                            ? Colors.white
                            : ParentColors.primary,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle:
                        const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
              if (canShare) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _shareWhatsApp(context, copyText);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share on WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => _infoRow(label, value);

  // ---------- small pieces ----------
  Widget _sectionTitle(String title, String? trailing) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark)),
          ),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ParentColors.muted)),
        ],
      ),
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
              'Fee details are entered by the school office. Online (UPI) '
                  'payments show as Paid only after the school verifies them.',
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

/// label — value ओळ (sheets मध्ये वापरतो).
Widget _infoRow(String label, String value, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  color: ParentColors.muted,
                  fontWeight: FontWeight.w600)),
        ),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  color: ParentColors.dark,
                  fontWeight: FontWeight.w800)),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}

// =====================================================================
// PAY ONLINE SHEET (UPI)
// ---------------------------------------------------------------------
// Step 1: UPI app उघडतो (upi://pay ...) — रक्कम, school चं नाव आधीच भरलेलं.
//         UPI app मधून परत आलो की UTR box आपोआप focus होतो.
// Step 2: Payment झाल्यावर UPI reference (UTR) टाकून, "I confirm" tick करून
//         school ला verify साठी पाठवतो.
// =====================================================================
class _PaySheet extends StatefulWidget {
  const _PaySheet({
    required this.fee,
    required this.studentName,
    required this.className,
    required this.upiId,
    required this.upiName,
    required this.onSubmit,
    required this.onDone,
    this.rejectedNote,
  });

  final FeeItem fee;
  final String studentName;
  final String className;

  /// रिकामा असेल तर school ने अजून UPI सेट केलेला नाही.
  final String upiId;
  final String upiName;
  final String? rejectedNote;

  /// null = यशस्वी, नाहीतर error text.
  final Future<String?> Function(String utr) onSubmit;
  final VoidCallback onDone;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> with WidgetsBindingObserver {
  final _utr = TextEditingController();
  final _utrFocus = FocusNode();
  bool _busy = false;
  bool _confirmed = false;

  /// UPI app उघडला गेला (परत आल्यावर UTR टाकायला सांगण्यासाठी).
  bool _launched = false;
  bool _backFromApp = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _utr.dispose();
    _utrFocus.dispose();
    super.dispose();
  }

  /// UPI app मधून आपल्या app मध्ये परत आलो -> UTR box कडे नेतो.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _launched && !_backFromApp) {
      setState(() => _backFromApp = true);
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted && !_busy) _utrFocus.requestFocus();
      });
    }
  }

  /// TEST MODE: खरा UPI app न उघडता खोटा (TEST) payment तयार करतो.
  void _simulatePay() {
    final n = DateTime.now().microsecondsSinceEpoch % 100000000;
    final utr = 'TEST${n.toString().padLeft(8, '0')}';
    _utr.value = TextEditingValue(
      text: utr,
      selection: TextSelection.collapsed(offset: utr.length),
    );
    setState(() {
      _confirmed = true;
      _error = null;
    });
    showSnack(context, 'Test payment done (no real money). Now tap Submit.');
  }

  Future<void> _launchUpi() async {
    if (_kTestPaymentMode) return; // TEST MODE मध्ये खरा UPI कधीच उघडत नाही
    final f = widget.fee;
    final note = '${f.title} ${widget.studentName}';
    final uri = Uri.parse(
      'upi://pay?pa=${widget.upiId}'
          '&pn=${Uri.encodeComponent(widget.upiName)}'
          '&am=${f.amount}.00'
          '&cu=INR'
          '&tn=${Uri.encodeComponent(note)}',
    );
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      _launched = true;
    } else {
      showSnack(context,
          'No UPI app found. Copy the UPI ID and pay from any UPI app.');
    }
  }

  Future<void> _copyUpi() async {
    await Clipboard.setData(ClipboardData(text: widget.upiId));
    if (mounted) showSnack(context, 'UPI ID copied');
  }

  /// Clipboard मधून UTR paste (फक्त अक्षरं / आकडे).
  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    var t = (data?.text ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (t.length > 22) t = t.substring(0, 22);
    if (!mounted) return;
    if (t.isEmpty) {
      showSnack(context, 'Nothing to paste. Copy the reference from your UPI app.');
      return;
    }
    _utr.value = TextEditingValue(
      text: t.toUpperCase(),
      selection: TextSelection.collapsed(offset: t.length),
    );
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final utr = _utr.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{8,22}$').hasMatch(utr)) {
      setState(() => _error =
      'Enter the UPI reference / UTR number from your payment app '
          '(8–22 letters or digits).');
      return;
    }
    // UPI चा UTR सहसा १२ आकडी असतो; फक्त आकडे असून लांबी वेगळी असेल तर चूक.
    if (RegExp(r'^[0-9]+$').hasMatch(utr) && utr.length != 12) {
      setState(() => _error =
      'A UPI reference made of digits is usually 12 digits long. '
          'Please check the number in your payment app.');
      return;
    }
    if (!_confirmed) {
      setState(() => _error =
      'Please tick the box to confirm that you have paid.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onSubmit(utr);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fee;
    const test = _kTestPaymentMode;
    final hasUpi = test || widget.upiId.isNotEmpty;

    return Padding(
      // Keyboard उघडल्यावर sheet वर सरकतो.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pay online',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: ParentColors.dark)),
              const SizedBox(height: 6),
              Text(rupees(f.amount),
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: ParentColors.primary)),
              const SizedBox(height: 14),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _infoRow('Fee', f.title),
                    _infoRow('Student',
                        '${widget.studentName} · ${widget.className}'),
                    if (test) _infoRow('Mode', 'TEST · no real money'),
                    if (!test && hasUpi) _infoRow('Pay to', widget.upiName),
                    if (!test && hasUpi)
                      _infoRow(
                        'UPI ID',
                        widget.upiId,
                        trailing: IconButton(
                          onPressed: _copyUpi,
                          tooltip: 'Copy UPI ID',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: ParentColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
              if (!hasUpi) ...[
                const SizedBox(height: 14),
                _infoBox(
                  Icons.info_outline_rounded,
                  'Online payment is not set up for this class yet. '
                      'Please pay at the school office (Cash / UPI).',
                  ParentColors.muted,
                  AppColors.background,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParentColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ] else ...[
                if (widget.rejectedNote != null) ...[
                  const SizedBox(height: 12),
                  _infoBox(Icons.error_outline_rounded, widget.rejectedNote!,
                      _ParentFeesScreenState._dueFg,
                      _ParentFeesScreenState._dueBg),
                ],
                if (test) ...[
                  const SizedBox(height: 12),
                  _infoBox(
                    Icons.science_outlined,
                    'TEST MODE: no real money is sent and no UPI app opens. '
                        'Tap "Simulate payment" to create a test payment, then submit it.',
                    _ParentFeesScreenState._waitFg,
                    _ParentFeesScreenState._waitBg,
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Step 1 · Pay',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: ParentColors.dark)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                    _busy ? null : (test ? _simulatePay : _launchUpi),
                    icon: Icon(
                        test ? Icons.science_outlined : Icons.open_in_new_rounded,
                        size: 18),
                    label: Text(test
                        ? 'Simulate payment of ${rupees(f.amount)} (TEST)'
                        : 'Pay ${rupees(f.amount)} with UPI app'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParentColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Step 2 · After paying',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: ParentColors.dark)),
                const SizedBox(height: 4),
                if (_backFromApp) ...[
                  const SizedBox(height: 4),
                  _infoBox(
                    Icons.check_circle_outline_rounded,
                    'Back from your payment app? If the payment went '
                        'through, enter the UPI reference below and submit.',
                    _ParentFeesScreenState._paidFg,
                    _ParentFeesScreenState._paidBg,
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Enter the UPI reference (UTR) shown in your payment app, '
                      'so the school can verify and mark the fee as Paid.',
                  style: TextStyle(
                      fontSize: 11.5, color: ParentColors.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _utr,
                  focusNode: _utrFocus,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(22),
                  ],
                  decoration: InputDecoration(
                    hintText: 'UPI reference / UTR number',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                    suffixIcon: IconButton(
                      onPressed: _busy ? null : _paste,
                      tooltip: 'Paste',
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  test
                      ? 'Test mode: the reference starts with TEST and is filled in for you.'
                      : 'Find it in Google Pay / PhonePe / Paytm → open this payment '
                      '→ "UPI transaction ID" / "UTR" / "Reference no.".',
                  style: const TextStyle(
                      fontSize: 11, color: ParentColors.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _busy
                      ? null
                      : () => setState(() {
                    _confirmed = !_confirmed;
                    _error = null;
                  }),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(
                          value: _confirmed,
                          activeColor: ParentColors.primary,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                            _confirmed = v ?? false;
                            _error = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            test
                                ? 'I confirm this is a TEST payment of ${rupees(f.amount)} '
                                '(no real money).'
                                : 'I confirm that I have paid ${rupees(f.amount)} '
                                'to ${widget.upiName}.',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: ParentColors.dark,
                                height: 1.4,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: _ParentFeesScreenState._dueFg,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.check_circle_outline_rounded,
                        size: 18),
                    label: Text(_busy ? 'Submitting...' : 'I have paid · Submit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ParentColors.primary,
                      side: const BorderSide(color: ParentColors.primary),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox(IconData icon, String text, Color fg, Color bg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 11.5,
                    color: fg,
                    height: 1.4,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}