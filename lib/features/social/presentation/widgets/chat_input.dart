import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class ChatInput extends StatelessWidget {
  const ChatInput({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
    this.focusNode,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(top: BorderSide(color: context.colors.tabBarBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.tabBarBorder),
            color: context.colors.tabBarBackground,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(color: context.colors.textPrimary),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    hintStyle: TextStyle(color: context.colors.medium),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
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
                          strokeWidth: 2,
                          color: FlixieColors.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: onSend,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: FlixieColors.primary,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
