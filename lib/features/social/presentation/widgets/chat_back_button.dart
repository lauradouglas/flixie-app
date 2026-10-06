import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';

/// Returns to the previous page, or Home for a standalone notification.
class ChatBackButton extends StatelessWidget {
  const ChatBackButton({super.key});
  @override
  Widget build(BuildContext context) => const FlixieBackButton();
}
