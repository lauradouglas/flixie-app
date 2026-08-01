import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

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
          16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 10),
      decoration: const BoxDecoration(
        color: FlixieColors.background,
        border: Border(
          top: BorderSide(color: FlixieColors.tabBarBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: FlixieColors.tabBarBorder),
              ),
              child: const Icon(Icons.add_rounded,
                  color: FlixieColors.primary, size: 27),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: FlixieColors.tabBarBorder),
                  color: FlixieColors.tabBarBackground,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: FlixieColors.textPrimary),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: const InputDecoration(
                          hintText: 'Message…',
                          hintStyle: TextStyle(color: FlixieColors.medium),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                        ),
                      ),
                    ),
                    sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: FlixieColors.primary),
                            ),
                          )
                        : IconButton(
                            onPressed: onSend,
                            icon: const Icon(Icons.send_rounded,
                                color: FlixieColors.primary),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
