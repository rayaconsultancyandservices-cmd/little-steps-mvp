import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_widgets.dart';

class _Batch {
  _Batch(this.key, this.photos);
  final String key;
  final List<AdminPhoto> photos;
  AdminPhoto get first => photos.first;
}

/// Photos: Teacher ने share केलेले photos (Parent ला फक्त त्यांच्या मुलाचे / whole class).
/// Admin सर्व बघू शकतो आणि अयोग्य photo batch delete करू शकतो.
class AdminPhotosScreen extends StatefulWidget {
  const AdminPhotosScreen({super.key});

  @override
  State<AdminPhotosScreen> createState() => _AdminPhotosScreenState();
}

class _AdminPhotosScreenState extends State<AdminPhotosScreen> {
  String? _classFilter;
  String _shareFilter = 'all';

  List<_Batch> _batches(List<AdminPhoto> all) {
    final map = <String, List<AdminPhoto>>{};
    for (final p in all) {
      // batchId नसलेले जुने photos एकेक वेगळे.
      final k = p.batchId.isEmpty ? 'single_${p.classId}_${p.id}' : p.batchId;
      map.putIfAbsent(k, () => []).add(p);
    }
    return [for (final e in map.entries) _Batch(e.key, e.value)]
      ..sort((a, b) => b.first.sentAt.compareTo(a.first.sentAt));
  }

  Future<void> _delete(_Batch b) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete ${b.photos.length} photo(s)?',
      message: 'They will be removed from the Parent and Teacher apps.',
    );
    if (!ok) return;
    try {
      await AdminState.instance.deletePhotos(b.photos);
      if (mounted) adminSnack(context, 'Photos deleted');
    } catch (e) {
      if (mounted) adminSnack(context, AdminState.errorText(e), error: true);
    }
  }

  Future<void> _open(_Batch b) async {
    final s = AdminState.instance;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('${s.classNameOf(b.first.classId)} · ${fmtDate(b.first.sentAt)}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (b.first.caption.isNotEmpty) ...[
                  Text(b.first.caption,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final p in b.photos) _thumb(p, 120)],
                ),
                const SizedBox(height: 14),
                Text(_audienceText(s, b),
                    style: const TextStyle(
                        fontSize: 12, color: AdminColors.muted)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _audienceText(AdminState s, _Batch b) {
    if (b.first.wholeClass) return 'Shared with the whole class';
    final ids = <String>{for (final p in b.photos) ...p.audience};
    if (ids.isEmpty) return 'Not shared with any parent (no child tagged)';
    return 'Shared with: ${ids.map(s.studentName).join(', ')}';
  }

  Widget _thumb(AdminPhoto p, double size) {
    final box = BoxDecoration(
      color: AdminColors.border,
      borderRadius: BorderRadius.circular(12),
    );
    if (p.url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: box,
        child: const Icon(Icons.image_not_supported_outlined,
            color: AdminColors.muted),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        p.url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: box,
          child: const Icon(Icons.broken_image_outlined,
              color: AdminColors.muted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AdminState.instance,
      builder: (context, _) {
        final s = AdminState.instance;
        final classPhotos = s.photos
            .where((p) => _classFilter == null || p.classId == _classFilter)
            .toList();
        final allBatches = _batches(classPhotos);
        final wholeClassCount = allBatches.where((b) => b.first.wholeClass).length;
        final taggedCount = allBatches.length - wholeClassCount;
        final batches = allBatches.where((b) {
          if (_shareFilter == 'whole') return b.first.wholeClass;
          if (_shareFilter == 'tagged') return !b.first.wholeClass;
          return true;
        }).toList();
        final visiblePhotos = batches.fold<int>(0, (n, b) => n + b.photos.length);

        return AdminPage(
          title: 'Photo gallery',
          subtitle: '${classPhotos.length} photos across ${allBatches.length} uploads',
          actions: [
            AdminDropdown<String?>(
              label: 'Class',
              width: 200,
              value: _classFilter,
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('All classes')),
                for (final c in s.classes)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.className)),
              ],
              onChanged: (v) => setState(() => _classFilter = v),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorBanner(s.lastError),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PhotoMetric(
                    label: 'Total photos',
                    value: '${classPhotos.length}',
                    icon: Icons.photo_library_outlined,
                    selected: _shareFilter == 'all',
                    onTap: () => setState(() => _shareFilter = 'all'),
                  ),
                  _PhotoMetric(
                    label: 'Uploads',
                    value: '${allBatches.length}',
                    icon: Icons.cloud_upload_outlined,
                    selected: _shareFilter == 'all',
                    onTap: () => setState(() => _shareFilter = 'all'),
                  ),
                  _PhotoMetric(
                    label: 'Whole class',
                    value: '$wholeClassCount',
                    icon: Icons.groups_outlined,
                    selected: _shareFilter == 'whole',
                    onTap: () => setState(() => _shareFilter = 'whole'),
                  ),
                  _PhotoMetric(
                    label: 'Tagged children',
                    value: '$taggedCount',
                    icon: Icons.person_pin_circle_outlined,
                    selected: _shareFilter == 'tagged',
                    onTap: () => setState(() => _shareFilter = 'tagged'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (batches.isEmpty)
                const AdminCard(
                  child: EmptyState('No photos have been shared yet.'),
                )
              else ...[
                if (_shareFilter != 'all') ...[
                  Row(
                    children: [
                      Text('${batches.length} uploads · $visiblePhotos photos',
                          style: const TextStyle(color: AdminColors.muted, fontSize: 12)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setState(() => _shareFilter = 'all'),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Clear filter'),
                      ),
                    ],
                  ),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [for (final b in batches) _card(s, b)],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _card(AdminState s, _Batch b) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _open(b),
            child: Row(
              children: [
                for (final p in b.photos.take(2)) ...[
                  _thumb(p, b.photos.length == 1 ? 236 : 112),
                  if (p != b.photos.take(2).last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            b.first.caption.isEmpty ? '(no caption)' : b.first.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${s.classNameOf(b.first.classId)} · ${fmtDate(b.first.sentAt)} · '
                '${b.photos.length} photo(s)',
            style: const TextStyle(fontSize: 11, color: AdminColors.muted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              StatusChip(
                b.first.wholeClass ? 'Whole class' : 'Tagged children',
                b.first.wholeClass ? AdminColors.green : AdminColors.blue,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'View',
                icon: const Icon(Icons.visibility_outlined, size: 19),
                onPressed: () => _open(b),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 19, color: AdminColors.red),
                onPressed: () => _delete(b),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoMetric extends StatelessWidget {
  const _PhotoMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: Material(
        color: selected ? const Color(0xFFEAF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AdminColors.blue : AdminColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : const Color(0xFFF3F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AdminColors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                    ],
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
