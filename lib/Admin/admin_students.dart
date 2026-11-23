import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'admin_state.dart';
import 'admin_widgets.dart';

/// Students: सर्व classes चे students – add / edit / delete.
class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen> {
  final _search = TextEditingController();
  String _q = '';
  String? _classFilter; // null = सर्व classes

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm({ChildInfo? existing}) async {
    final s = AdminState.instance;
    if (s.classes.isEmpty) {
      adminSnack(context, 'Create a class first (Classes tab).', error: true);
      return;
    }
    final result = await showDialog<ChildInfo>(
      context: context,
      builder: (_) => _StudentForm(existing: existing, defaultClassId: _classFilter),
    );
    if (result == null) return;
    try {
      await s.saveStudent(result, isNew: existing == null);
      if (mounted) {
        adminSnack(context, existing == null ? 'Student added' : 'Student updated');
      }
    } catch (e) {
      if (mounted) adminSnack(context, '$e', error: true);
    }
  }

  Future<void> _delete(ChildInfo c) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete ${c.name}?',
      message: 'The student record will be removed. The parent will no '
          'longer be able to see this child in the Parent app.',
    );
    if (!ok) return;
    try {
      await AdminState.instance.deleteStudent(c.id);
      if (mounted) adminSnack(context, 'Student deleted');
    } catch (e) {
      if (mounted) adminSnack(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final list = s.students.where((c) {
          if (_classFilter != null && c.classId != _classFilter) return false;
          if (_q.isEmpty) return true;
          return '${c.name} ${c.parentName} ${c.parentEmail} ${c.rollNo}'
              .toLowerCase()
              .contains(_q);
        }).toList();

        return AdminPage(
          title: 'Students',
          subtitle: '${list.length} of ${s.students.length} students',
          actions: [
            AdminSearchField(
              controller: _search,
              hint: 'Search student or parent…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            AdminDropdown<String?>(
              label: 'Class',
              width: 190,
              value: _classFilter,
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All classes')),
                for (final c in s.classes)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.className)),
              ],
              onChanged: (v) => setState(() => _classFilter = v),
            ),
            FilledButton.icon(
              style: adminPrimaryButton(),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add student'),
            ),
          ],
          child: Column(
            children: [
              ErrorBanner(s.lastError),
              AdminCard(
                child: AdminTable(
                  emptyText: s.students.isEmpty
                      ? 'No students yet. Add students here or from the '
                      'Teacher app.'
                      : 'No student matches the filter.',
                  columns: const [
                    'Roll',
                    'Name',
                    'Class',
                    'Gender',
                    'Age',
                    'Parent',
                    'Parent email',
                    'Parent app',
                    '',
                  ],
                  rows: [
                    for (final c in list)
                      DataRow(cells: [
                        cellText('${c.rollNo}'),
                        cellText(c.name, bold: true),
                        cellText(c.className),
                        cellText(c.gender),
                        cellText(c.ageLabel(DateTime.now())),
                        cellText(c.parentName),
                        cellText(c.parentEmail),
                        DataCell(s.parentJoined(c)
                            ? const StatusChip('Joined', AdminColors.green)
                            : const StatusChip('Not yet', AdminColors.orange)),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined, size: 19),
                              onPressed: () => _openForm(existing: c),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 19, color: AdminColors.red),
                              onPressed: () => _delete(c),
                            ),
                          ],
                        )),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentForm extends StatefulWidget {
  const _StudentForm({this.existing, this.defaultClassId});

  final ChildInfo? existing;
  final String? defaultClassId;

  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _roll;
  late final TextEditingController _parent;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _allergy;
  late final TextEditingController _pickup;

  String? _classId;
  String _gender = 'Boy';
  String? _blood;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final s = AdminState.instance;
    _name = TextEditingController(text: e?.name ?? '');
    _parent = TextEditingController(text: e?.parentName ?? '');
    _email = TextEditingController(text: e?.parentEmail ?? '');
    _phone = TextEditingController(
      text: (e != null && e.contacts.isNotEmpty) ? e.contacts.first.phone : '',
    );
    _allergy = TextEditingController(text: e?.allergyNote ?? '');
    _pickup = TextEditingController(text: e?.pickupNote ?? '');

    _classId = e?.classId ?? widget.defaultClassId;
    if (_classId != null && !s.classes.any((c) => c.id == _classId)) {
      _classId = null;
    }
    _classId ??= s.classes.isNotEmpty ? s.classes.first.id : null;

    _roll = TextEditingController(
      text: e != null
          ? '${e.rollNo}'
          : '${_classId == null ? 1 : s.nextRollFor(_classId!)}',
    );
    if (e != null) {
      _gender = (e.gender == 'Girl') ? 'Girl' : 'Boy';
      _blood = _bloodGroups.contains(e.bloodGroup) ? e.bloodGroup : null;
      _dob = e.dob;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    _parent.dispose();
    _email.dispose();
    _phone.dispose();
    _allergy.dispose();
    _pickup.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 3, 1, 1),
      firstDate: DateTime(now.year - 12),
      lastDate: now,
    );
    if (d != null) setState(() => _dob = d);
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _classId == null) return;
    final s = AdminState.instance;
    final cls = s.classes.firstWhere((c) => c.id == _classId);
    final phone = _phone.text.trim();
    final e = widget.existing;

    Navigator.pop(
      context,
      ChildInfo(
        id: e?.id ?? '',
        name: _name.text.trim(),
        className: cls.className,
        classId: cls.id,
        rollNo: int.tryParse(_roll.text.trim()) ?? s.nextRollFor(cls.id),
        dob: _dob ?? DateTime(DateTime.now().year - 3, 1, 1),
        bloodGroup: _blood ?? '',
        gender: _gender,
        allergyNote: _allergy.text.trim(),
        parentName: _parent.text.trim(),
        parentEmail: _email.text.trim().toLowerCase(),
        pickupNote: _pickup.text.trim(),
        contacts: phone.isEmpty
            ? const []
            : [ParentContact(_parent.text.trim(), 'Parent', phone)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminState.instance;
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(isEdit ? 'Edit student' : 'Add student'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogField(_name, 'Student name', required: true),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _classId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: [
                            for (final c in s.classes)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(c.className),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            _classId = v;
                            if (!isEdit && v != null) {
                              _roll.text = '${s.nextRollFor(v)}';
                            }
                          }),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: dialogField(
                        _roll,
                        'Roll no',
                        keyboard: TextInputType.number,
                        validator: (v) =>
                        int.tryParse((v ?? '').trim()) == null ? 'Number' : null,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    for (final g in const ['Boy', 'Girl']) ...[
                      ChoiceChip(
                        label: Text(g),
                        selected: _gender == g,
                        onSelected: (_) => setState(() => _gender = g),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _pickDob,
                      icon: const Icon(Icons.cake_outlined, size: 18),
                      label: Text(_dob == null ? 'Date of birth' : fmtDate(_dob)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: _blood,
                    decoration: const InputDecoration(labelText: 'Blood group'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Not set')),
                      for (final b in _bloodGroups)
                        DropdownMenuItem<String?>(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() => _blood = v),
                  ),
                ),
                dialogField(_allergy, 'Allergy / medical note'),
                const Divider(),
                const SizedBox(height: 8),
                dialogField(_parent, 'Parent name', required: true),
                dialogField(
                  _email,
                  'Parent email (used for Parent app login)',
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Required';
                    return t.contains('@') ? null : 'Enter a valid email';
                  },
                ),
                dialogField(_phone, 'Parent phone', keyboard: TextInputType.phone),
                dialogField(_pickup, 'Pickup note', maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: adminPrimaryButton(),
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add student'),
        ),
      ],
    );
  }
}