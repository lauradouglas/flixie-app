import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class GroupDeletionOverlay extends StatelessWidget {
  const GroupDeletionOverlay({super.key});
  @override
  Widget build(BuildContext context) => Stack(children: [
        const Positioned.fill(
          child: ModalBarrier(
            dismissible: false,
            color: Color(0x99000000),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                        color: FlixieColors.primary),
                    const SizedBox(height: 14),
                    Text(
                      'Deleting group…',
                      style: TextStyle(
                        color: context.colors.light,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Removing lists, requests and messages',
                      style: TextStyle(
                        color: context.colors.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]);
}
