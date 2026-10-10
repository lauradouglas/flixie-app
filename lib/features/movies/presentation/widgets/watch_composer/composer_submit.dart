import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../controllers/watch_composer_controller.dart';
import '../../watch_composer_actions.dart';

class ComposerSubmit extends StatelessWidget {
  const ComposerSubmit(
      {super.key,
      required this.controller,
      required this.actions,
      required this.messageController});
  final WatchComposerController controller;
  final WatchComposerActions actions;
  final TextEditingController messageController;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              'Message',
              style: TextStyle(
                color: context.colors.light,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'OPTIONAL',
              style: TextStyle(
                color: context.colors.medium,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: messageController,
          minLines: 1,
          maxLines: 2,
          style: TextStyle(color: context.colors.light),
          decoration: InputDecoration(
            hintText: 'e.g. Want to watch this together?',
            hintStyle: TextStyle(color: context.colors.medium, fontSize: 13),
            filled: true,
            fillColor: context.colors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.colors.tabBarBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.colors.tabBarBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: FlixieColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FlixieColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: context.colors.surfaceElevated,
              disabledForegroundColor: context.colors.medium,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: FlixieColors.primary),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            onPressed: controller.canSend
                ? () => actions.send(messageController.text)
                : null,
            child: controller.isSending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(controller.sendButtonLabel),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'The plan stays in Planning until a movie and time are agreed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.medium, fontSize: 12),
          ),
        ),
      ]);
}
