import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ChatInput extends StatelessWidget {
  const ChatInput({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: const BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        border: Border(
          top: BorderSide(color: FlixieColors.tabBarBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: FlixieColors.light),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: const TextStyle(color: FlixieColors.medium),
                  filled: true,
                  fillColor: FlixieColors.tabBarBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: FlixieColors.primary),
                  )
                : IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded,
                        color: FlixieColors.primary),
                  ),
          ],
        ),
      ),
    );
  }
}
