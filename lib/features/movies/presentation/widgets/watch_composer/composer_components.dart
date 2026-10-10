import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class PlanStepHeading extends StatelessWidget {
  const PlanStepHeading(
      {super.key, required this.number, required this.title, this.trailing});
  final String number;
  final String title;
  final String? trailing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final titleWidget = Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.colors.light, fontWeight: FontWeight.w900),
          );
          final numberWidget = CircleAvatar(
            radius: 18,
            backgroundColor: FlixieColors.primary,
            child: Text(number,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w800)),
          );
          final trailingWidget = trailing == null
              ? null
              : Text(trailing!,
                  style: TextStyle(
                      color: context.colors.medium,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5));
          if (trailingWidget == null || constraints.maxWidth < 390) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    numberWidget,
                    const SizedBox(width: 10),
                    Expanded(child: titleWidget)
                  ]),
                  if (trailingWidget != null) ...[
                    const SizedBox(height: 5),
                    trailingWidget,
                  ],
                ]);
          }
          return Row(children: [
            numberWidget,
            const SizedBox(width: 10),
            Expanded(child: titleWidget),
            const SizedBox(width: 8),
            trailingWidget,
          ]);
        },
      );
}

class SchedulePicker extends StatelessWidget {
  const SchedulePicker(
      {super.key,
      required this.label,
      required this.value,
      required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              border: Border.all(color: context.colors.tabBarBorder),
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: context.colors.medium,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: context.colors.light,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class ModeTab extends StatelessWidget {
  const ModeTab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? FlixieColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon,
                size: 17,
                color: selected ? Colors.white : context.colors.medium),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : context.colors.medium,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
