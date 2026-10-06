import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

/// Duyuru oluşturma / düzenleme formu.
///
/// Başlık, içerik, hedef gruplar, yayın tarihi, son geçerlilik, görsel ve
/// dosya eki. Görsel Storage'a yüklenir; push bildirimini Cloud Functions
/// trigger'ı gönderir.
class AnnouncementFormScreen extends StatefulWidget {
  const AnnouncementFormScreen({super.key, this.announcement});

  final Announcement? announcement;

  static Future<void> open(BuildContext context, {Announcement? announcement}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnnouncementFormScreen(announcement: announcement),
        ),
      );

  @override
  State<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.announcement?.title ?? '');
  late final _content = TextEditingController(text: widget.announcement?.content ?? '');

  final Set<String> _selectedGroups = {};
  late DateTime? _publishedAt = widget.announcement?.publishedAt;
  late DateTime? _expiresAt = widget.announcement?.expiresAt;
  Attachment? _image;
  bool _saving = false;

  bool get _isEdit => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    _selectedGroups.addAll(widget.announcement?.targetGroupIds ?? const []);
    _image = widget.announcement?.attachments.isNotEmpty == true
        ? widget.announcement!.attachments.first
        : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final uploads = context.read<UploadRepository>();
    final files = await FilePicker.pickFiles(type: FileType.image);
    final path = files.isEmpty ? null : files.single.path;
    if (path == null || !mounted) return;

    final file = File(path);
    final error = UploadRepository.validate(file);
    if (error.isNotEmpty) {
      _showError(error);
      return;
    }

    try {
      final attachment = await uploads.uploadAnnouncementImage(
        announcementId: widget.announcement?.id ?? 'draft-${DateTime.now().millisecondsSinceEpoch}',
        file: file,
        functionName: 'image',
      );
      if (!mounted) return;
      setState(() => _image = attachment);
    } catch (error) {
      _showError('Görsel yüklenemedi: $error');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repository = context.read<AnnouncementRepository>();
    final targets = _selectedGroups.toList();

    try {
      if (_isEdit) {
        await repository.update(
          id: widget.announcement!.id,
          title: _title.text.trim(),
          content: _content.text.trim(),
          targetGroupIds: targets,
          expiresAt: _expiresAt,
          imageUrl: _image?.url,
          attachments: _image == null ? const [] : [_image!],
        );
      } else {
        await repository.create(
          title: _title.text.trim(),
          content: _content.text.trim(),
          targetGroupIds: targets,
          publishedAt: _publishedAt,
          expiresAt: _expiresAt,
          imageUrl: _image?.url,
          attachments: _image == null ? const [] : [_image!],
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Duyuru güncellendi.' : 'Duyuru yayınlandı.')),
      );
    } catch (error) {
      _showError('Kaydedilemedi: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate({required bool isPublished}) async {
    final initial = (isPublished ? _publishedAt : _expiresAt) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isPublished) {
        _publishedAt = picked;
      } else {
        _expiresAt = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupRepository>();

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Duyuruyu düzenle' : 'Yeni duyuru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Başlık zorunludur.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _content,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'İçerik',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'İçerik zorunludur.' : null,
            ),
            const SizedBox(height: 20),
            Text(
              'Hedef gruplar',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Hiçbir grup seçilmezse duyuru tüm öğrencilere gider.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<AppGroup>>(
              stream: groups.watchAllGroups(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <AppGroup>[];
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: AppLoading(),
                  );
                }
                if (items.isEmpty) {
                  return const Text('Henüz grup yok.');
                }
                return Column(
                  children: [
                    for (final group in items)
                      CheckboxListTile(
                        dense: true,
                        value: _selectedGroups.contains(group.id),
                        title: Text(group.name),
                        subtitle: Text('${group.memberCount} üye'),
                        onChanged: (checked) => setState(() {
                          if (checked ?? false) {
                            _selectedGroups.add(group.id);
                          } else {
                            _selectedGroups.remove(group.id);
                          }
                        }),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _DateTile(
              icon: Icons.event_rounded,
              label: 'Yayın tarihi',
              value: _publishedAt == null ? 'Hemen' : AppDate.dateTime(_publishedAt!),
              onTap: () => _pickDate(isPublished: true),
              onClear: _isEdit
                  ? null
                  : () => setState(() => _publishedAt = null),
            ),
            _DateTile(
              icon: Icons.event_busy_rounded,
              label: 'Son geçerlilik',
              value: _expiresAt == null ? 'Süresiz' : AppDate.date(_expiresAt!),
              onTap: () => _pickDate(isPublished: false),
              onClear: () => setState(() => _expiresAt = null),
            ),
            const SizedBox(height: 16),
            Text(
              'Görsel / dosya eki',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AttachmentTile(
                  attachment: _image!,
                  onTap: () => setState(() => _image = null),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Görsel seç'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isEdit ? 'Değişiklikleri kaydet' : 'Duyuruyu yayınla'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value),
        trailing: onClear == null
            ? const Icon(Icons.chevron_right_rounded)
            : IconButton(onPressed: onClear, icon: const Icon(Icons.clear_rounded)),
        onTap: onTap,
      );
}
