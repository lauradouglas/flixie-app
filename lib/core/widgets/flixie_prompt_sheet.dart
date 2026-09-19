import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

Future<T?> showFlixiePromptSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    showDragHandle: isDismissible,
    backgroundColor: context.colors.surface,
    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, isDismissible ? 0 : 24, 24,
              24 + MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(width: double.infinity, child: builder(context)),
        ),
      ),
    ),
  );
}

class FlixiePromptSheetContent extends StatelessWidget {
  const FlixiePromptSheetContent(
      {super.key,
      required this.title,
      required this.content,
      required this.actions});
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle.merge(
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.colors.white),
            child: title,
          ),
          const SizedBox(height: 16),
          DefaultTextStyle.merge(
            style: TextStyle(
                fontSize: 16, height: 1.5, color: context.colors.light),
            child: content,
          ),
          const SizedBox(height: 24),
          Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: actions)),
        ],
      );
}
