import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'parent_home_screen.dart' show ParentColors;

/// नवीन: Parent ला पहिल्या login ला दिसणारी Consent screen (Figma A3 प्रमाणे).
///
/// दोन प्रश्न:
///  1) Face recognition (AI हजेरी) ला परवानगी?
///  2) मुलाचे photos पाठवायला / शेअर करायला परवानगी?
/// दोन्हीला Yes / No उत्तर दिल्याशिवाय पुढे जाता येत नाही.
/// उत्तर students/{id} मध्ये (consentFace, consentPhotos, consentAt) सेव्ह होतं,
/// मग ParentShell आपोआप Home दाखवतो.
class ParentConsentScreen extends StatefulWidget {
  const ParentConsentScreen({super.key, this.onLogout});

  /// "Logout" बटण (Parent ला consent द्यायची नसेल तर बाहेर पडण्यासाठी).
  final VoidCallback? onLogout;

  @override
  State<ParentConsentScreen> createState() => _ParentConsentScreenState();
}

class _ParentConsentScreenState extends State<ParentConsentScreen> {
  bool? _face;
  bool? _photos;
  bool _saving = false;

  Future<void> _save() async {
    if (_face == null || _photos == null || _saving) return;
    setState(() => _saving = true);
    final err = await AppState.instance
        .saveParentConsent(face: _face!, photos: _photos!);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
    // यशस्वी झालं तर ParentShell AppState ऐकतो आणि स्वतः Home दाखवतो.
  }

  @override
  Widget build(BuildContext context) {
    final name = AppState.instance.child.firstName;
    final canSave = _face != null && _photos != null && !_saving;

    return Scaffold(
      backgroundColor: ParentColors.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (widget.onLogout != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _saving ? null : widget.onLogout,
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: ParentColors.muted),
                      ),
                    ),
                  ),
                const Text(
                  'Before you start',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: ParentColors.dark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name.isEmpty
                      ? 'Please tell us what you are comfortable with.'
                      : 'Please tell us what you are comfortable with '
                      'for $name.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: ParentColors.muted,
                  ),
                ),
                const SizedBox(height: 18),
                _ConsentCard(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'Face recognition for attendance',
                  body: 'The teacher takes a class photo and the app helps '
                      'mark attendance. If you say No, the teacher always '
                      'marks $name manually.',
                  value: _face,
                  onChanged: (v) => setState(() => _face = v),
                ),
                const SizedBox(height: 14),
                _ConsentCard(
                  icon: Icons.photo_camera_outlined,
                  title: 'Photos of my child',
                  body: 'The teacher may send you photos from class activities '
                      'in which $name appears. If you say No, $name will not '
                      'be tagged in photos.',
                  value: _photos,
                  onChanged: (v) => setState(() => _photos = v),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: canSave ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParentColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: ParentColors.border,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Save & continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please answer both questions to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: ParentColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParentColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: ParentColors.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: ParentColors.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ParentColors.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: ParentColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _choice('Yes, allow', true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _choice('No', false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, bool v) {
    final selected = value == v;
    return InkWell(
      onTap: () => onChanged(v),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ParentColors.primary : ParentColors.tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : ParentColors.primary,
          ),
        ),
      ),
    );
  }
}