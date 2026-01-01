import 'package:flutter/material.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
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
    await _vm.sendUserMessage(text);
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
                      child: Row(
                        children: [
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
          child: Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(color: fg),
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


