import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../repositories/message_repository.dart';
import '../repositories/upload_repository.dart';
import '../services/firebase_services.dart';

/// Mesaj yazma alanı + dosya eki.
///
/// Mesaj kimliği önce üretilir, dosya Storage'a o kimliğin altına yazılır;
/// böylece kuralların "üye kendi mesajına ek yükleyebilir" kontrolü tutar.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.groupId,
    required this.services,
    this.hint = 'Mesajınızı yazın…',
  });

  final String groupId;
  final FirebaseServices services;
  final String hint;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  File? _pendingFile;
  bool _sending = false;

  MessageRepository get _messages => MessageRepository(services: widget.services);
  UploadRepository get _uploads => UploadRepository(services: widget.services);


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // file_picker 13: pickFiles artık statik, List<PlatformFile> döner.
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
    );
    final path = (files.isEmpty ? null : files.single.path);
    if (path == null || !mounted) return;

    final file = File(path);
    final error = UploadRepository.validate(file);
    if (error.isNotEmpty) {
      _showError(error);
      return;
    }
    setState(() => _pendingFile = file);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingFile == null) return;

    setState(() => _sending = true);

    try {
      // Mesaj kimliği dosya yüklemesinden önce üretilir.
      final messageId = _messages.createMessageId();
      final attachments = <Attachment>[];

      if (_pendingFile != null) {
        attachments.add(
          await _uploads.uploadMessageAttachment(
            groupId: widget.groupId,
            messageId: messageId,
            file: _pendingFile!,
          ),
        );
      }

      await _messages.sendWithId(
        groupId: widget.groupId,
        messageId: messageId,
        content: text,
        attachments: attachments,
      );

      _controller.clear();
      setState(() => _pendingFile = null);
    } catch (error) {
      _showError('Mesaj gönderilemedi: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.attach_file_rounded, size: 18, color: scheme.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _pendingFile!.path.split(RegExp(r'[/\\]')).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _pendingFile = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _pickFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  tooltip: 'Dosya ekle',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(hintText: widget.hint, isDense: true),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
