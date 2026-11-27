import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/page_app_bar.dart';
import 'student_profile_screen.dart';

/// Teacher साठी: "My Students" — वर्गातील सर्व मुलांची यादी.
///
/// * Search (नाव / roll no / parent चं नाव) + filter chips (All / Boys / Girls / Allergy)
/// * मुलावर टॅप केलं की त्याचं पूर्ण Student Profile उघडतं.
/// * रंग/style Attendance screen प्रमाणेच (background 0xFFF4F8F7, primary 0xFF168C80).
class MyStudentsScreen extends StatefulWidget {
  const MyStudentsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MyStudentsScreen> createState() => _MyStudentsScreenState();
}

class _MyStudentsScreenState extends State<MyStudentsScreen> {
  static const Color primary = Color(0xFF168C80);
  static const Color dark = Color(0xFF183B45);
  static const Color muted = Color(0xFF84918D);
  static const Color orange = Color(0xFFD99437);
  static const Color border = Color(0xFFE5ECE9);

  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _filter = 0; // 0 All, 1 Boys, 2 Girls, 3 Allergy

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onState);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onState);
    _search.dispose();
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------
  List<ChildInfo> get _all {
    final list = List<ChildInfo>.from(AppState.instance.students);
    list.sort((a, b) {
      final r = a.rollNo.compareTo(b.rollNo);
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  bool _isGirl(ChildInfo c) => c.gender.toLowerCase() == 'girl';
  bool _isBoy(ChildInfo c) => c.gender.toLowerCase() == 'boy';
  bool _hasAllergy(ChildInfo c) => c.allergyNote.trim().isNotEmpty;

  List<ChildInfo> get _visible {
    final q = _query.trim().toLowerCase();
    return _all.where((c) {
      if (_filter == 1 && !_isBoy(c)) return false;
      if (_filter == 2 && !_isGirl(c)) return false;
      if (_filter == 3 && !_hasAllergy(c)) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.parentName.toLowerCase().contains(q) ||
          '${c.rollNo}' == q;
    }).toList();
  }

  void _open(ChildInfo c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentProfileScreen(studentId: c.id),
      ),
    );
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final all = _all;
    final list = _visible;
    final boys = all.where(_isBoy).length;
    final girls = all.where(_isGirl).length;
    final allergy = all.where(_hasAllergy).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),
      appBar: buildPageAppBar(
        title: 'My Students',
        subtitle: '${AppState.instance.className} · ${all.length} students',
        onBack: widget.onBack,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          // SUMMARY
          Row(
            children: [
              Expanded(
                child: _summaryCard('Total', all.length, primary,
                    const Color(0xFFE5F5F0), Icons.groups_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard('Boys', boys, const Color(0xFF4779C8),
                    const Color(0xFFEAF1FF), Icons.boy_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard('Girls', girls, const Color(0xFFCA6B91),
                    const Color(0xFFFFEDF3), Icons.girl_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _buildSearch(),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All', 0, all.length),
                _chip('Boys', 1, boys),
                _chip('Girls', 2, girls),
                _chip('Allergy', 3, allergy),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (all.isEmpty)
            _empty('No students in your class yet.\n'
                'Please ask the school admin to add students.')
          else if (list.isEmpty)
            _empty('No student matches your search.')
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    _studentTile(list[i]),
                    if (i != list.length - 1)
                      const Divider(
                        height: 1,
                        indent: 70,
                        endIndent: 14,
                        color: Color(0xFFEFF3F1),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// लहान (compact) summary pill: icon + आकडा + नाव एकाच ओळीत.
  Widget _summaryCard(
      String label, int value, Color color, Color light, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
        color: light,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Search by name, roll no or parent...',
        hintStyle: const TextStyle(color: Color(0xFFA1ADA8), fontSize: 12),
        prefixIcon: const Icon(Icons.search_rounded, color: primary),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
          onPressed: () {
            _search.clear();
            setState(() => _query = '');
          },
          icon: const Icon(Icons.close_rounded),
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _chip(String label, int index, int count) {
    final selected = _filter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = index),
        backgroundColor: Colors.white,
        selectedColor: primary,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? primary : border),
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : dark,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white70 : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentTile(ChildInfo c) {
    final age = c.ageLabel(DateTime.now());
    final sub = [
      'Roll ${c.rollNo}',
      age,
      if (c.gender.isNotEmpty) c.gender,
    ].join(' · ');

    return InkWell(
      onTap: () => _open(c),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            StudentAvatar(child: c, radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: dark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (c.parentName.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Parent: ${c.parentName.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ],
              ),
            ),
            if (_hasAllergy(c))
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 15, color: orange),
              ),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          const Icon(Icons.groups_rounded, size: 34, color: muted),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: muted,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}