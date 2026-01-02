import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_attachment.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_message.dart';
import 'package:spend_mate/ui/features/ai_chat/view_models/ai_chat_view_model.dart';
import 'package:spend_mate/ui/features/settings/ai_provider_settings_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    required this.configRepository,
  });

  final AiProviderConfigRepository configRepository;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  late final AiChatViewModel _vm;
  late final Future<void> _initFuture;
  final _controller = TextEditingController();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _vm = AiChatViewModel(configRepository: widget.configRepository);
    _initFuture = _vm.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiProviderSettingsScreen(
          configRepository: widget.configRepository,
        ),
      ),
    );
    await _vm.reloadConfig();
  }

  Future<void> _send() async {
    final text = _controller.text;
    _controller.clear();
    await _vm.sendUserMessage(text: text);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null) return;
      if (!mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final mimeType = picked.mimeType ?? _guessMimeType(picked.name);
      _vm.addPendingAttachment(
        ChatAttachment(
          type: ChatAttachmentType.image,
          name: picked.name,
          mimeType: mimeType,
          bytes: bytes,
        ),
      );
    } catch (e) {
      _vm.setError('Failed to pick image: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;
      if (!mounted) return;
      for (final file in result.files) {
        final bytes = file.bytes ??
            (file.path == null ? null : await File(file.path!).readAsBytes());
        if (!mounted) return;
        if (bytes == null) {
          _vm.setError('Unable to read ${file.name}.');
          continue;
        }
        final mimeType = _guessMimeType(file.name);
        final type = mimeType.startsWith('image/')
            ? ChatAttachmentType.image
            : ChatAttachmentType.file;
        _vm.addPendingAttachment(
          ChatAttachment(
            type: type,
            name: file.name,
            mimeType: mimeType,
            bytes: bytes,
          ),
        );
      }
    } catch (e) {
      _vm.setError('Failed to pick file: $e');
    }
  }

  void _openImagePickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _guessMimeType(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) {
      return 'application/octet-stream';
    }
    final ext = name.substring(dotIndex + 1).toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'pdf' => 'application/pdf',
      'csv' => 'text/csv',
      'txt' => 'text/plain',
      'json' => 'application/json',
      'xml' => 'application/xml',
      _ => 'application/octet-stream',
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return AnimatedBuilder(
          animation: _vm,
          builder: (context, _) {
            final visible = _vm.messages
                .where((m) => m.role != ChatRole.system)
                .toList(growable: false);

            return Scaffold(
              appBar: AppBar(
                title: const Text('AI Chat'),
                actions: [
                  IconButton(
                    tooltip: 'AI settings',
                    onPressed: () {
                      _openSettings();
                    },
                    icon: const Icon(Icons.settings),
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (_vm.error != null)
                    MaterialBanner(
                      content: Text(_vm.error!),
                      leading: const Icon(Icons.error_outline),
                      actions: [
                        TextButton(
                          onPressed: _vm.clearError,
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: visible.length + (_vm.isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_vm.isSending && index == 0) {
                          return const _TypingIndicator();
                        }
                        final msgIndex =
                            visible.length - 1 - (index - (_vm.isSending ? 1 : 0));
                        final message = visible[msgIndex];
                        return _ChatBubble(message: message);
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_vm.pendingAttachments.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _PendingAttachmentScroller(
                                attachments: _vm.pendingAttachments,
                                onRemove: _vm.removePendingAttachment,
                              ),
                            ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Add image',
                                onPressed:
                                    _vm.isSending ? null : _openImagePickerSheet,
                                icon: const Icon(Icons.image_outlined),
                              ),
                              IconButton(
                                tooltip: 'Add file',
                                onPressed: _vm.isSending ? null : _pickFiles,
                                icon: const Icon(Icons.attach_file),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 5,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) {
                                    if (_vm.isSending) return;
                                    _send();
                                  },
                                  decoration: const InputDecoration(
                                    hintText: 'Ask Spend Mate…',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                tooltip: 'Send',
                                onPressed: _vm.isSending
                                    ? null
                                    : () {
                                        _send();
                                      },
                                icon: const Icon(Icons.send),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);

    final bg = isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.attachments.isNotEmpty)
                _MessageAttachmentWrap(
                  attachments: message.attachments,
                  background: bg,
                  foreground: fg,
                ),
              if (message.attachments.isNotEmpty &&
                  message.text.trim().isNotEmpty)
                const SizedBox(height: 8),
              if (message.text.trim().isNotEmpty)
                Text(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Thinking…'),
          ],
        ),
      ),
    );
  }
}

class _PendingAttachmentScroller extends StatelessWidget {
  const _PendingAttachmentScroller({
    required this.attachments,
    required this.onRemove,
  });

  final List<ChatAttachment> attachments;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _AttachmentTile(
            attachment: attachment,
            onRemove: onRemove,
          );
        },
      ),
    );
  }
}

class _MessageAttachmentWrap extends StatelessWidget {
  const _MessageAttachmentWrap({
    required this.attachments,
    required this.background,
    required this.foreground,
  });

  final List<ChatAttachment> attachments;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final attachment in attachments)
          _AttachmentTile(
            attachment: attachment,
            background: background,
            foreground: foreground,
          ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    this.onRemove,
    this.background,
    this.foreground,
  });

  final ChatAttachment attachment;
  final void Function(String id)? onRemove;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = background ?? theme.colorScheme.surfaceContainerHighest;
    final fg = foreground ?? theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 40,
                  width: double.infinity,
                  child: attachment.isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            attachment.bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              color: fg,
                              size: 30,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.insert_drive_file_outlined,
                          color: fg,
                          size: 30,
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: fg),
                  textAlign: TextAlign.center,
                ),
                Text(
                  attachment.sizeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: fg),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: -6,
              top: -6,
              child: IconButton(
                tooltip: 'Remove',
                onPressed: () => onRemove?.call(attachment.id),
                iconSize: 18,
                color: theme.colorScheme.error,
                icon: const Icon(Icons.cancel),
              ),
            ),
        ],
      ),
    );
  }
}
