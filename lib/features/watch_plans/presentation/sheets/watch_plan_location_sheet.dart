import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

enum WatchLocationKind { home, cinema, later }

class WatchPlanLocationSheet extends StatefulWidget {
  const WatchPlanLocationSheet({super.key, this.initialLocation});
  final String? initialLocation;

  @override
  State<WatchPlanLocationSheet> createState() => _WatchPlanLocationSheetState();
}

class _WatchPlanLocationSheetState extends State<WatchPlanLocationSheet> {
  late final TextEditingController _locationController;
  late WatchLocationKind _kind;

  @override
  void initState() {
    super.initState();
    _locationController =
        TextEditingController(text: widget.initialLocation ?? '');
    _kind = widget.initialLocation?.trim().isNotEmpty == true
        ? WatchLocationKind.cinema
        : WatchLocationKind.later;
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .84,
        child: Material(
          color: FlixieColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  24, 14, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 54,
                            height: 6,
                            decoration: BoxDecoration(
                                color: FlixieColors.medium,
                                borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(height: 24),
                    Row(children: [
                      const Expanded(
                          child: Text('Where are you watching?',
                              style: TextStyle(
                                  color: FlixieColors.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800))),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: FlixieColors.light, size: 28)),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                        'Choose the kind of plan first. A specific place is optional.',
                        style:
                            TextStyle(color: FlixieColors.light, fontSize: 13)),
                    const SizedBox(height: 24),
                    _LocationKindOption(
                        kind: WatchLocationKind.home,
                        selected: _kind,
                        icon: Icons.home_outlined,
                        title: 'At home',
                        subtitle: 'Check shared streaming providers',
                        onTap: () =>
                            setState(() => _kind = WatchLocationKind.home)),
                    const SizedBox(height: 10),
                    _LocationKindOption(
                        kind: WatchLocationKind.cinema,
                        selected: _kind,
                        icon: Icons.theaters_outlined,
                        title: 'Cinema',
                        subtitle: 'Streaming providers don’t matter',
                        onTap: () =>
                            setState(() => _kind = WatchLocationKind.cinema)),
                    const SizedBox(height: 10),
                    _LocationKindOption(
                        kind: WatchLocationKind.later,
                        selected: _kind,
                        icon: Icons.more_horiz_rounded,
                        title: 'Decide later',
                        subtitle: 'Keep the plan flexible',
                        onTap: () =>
                            setState(() => _kind = WatchLocationKind.later)),
                    const SizedBox(height: 24),
                    Row(children: [
                      Text(
                          _kind == WatchLocationKind.cinema
                              ? 'Cinema'
                              : _kind == WatchLocationKind.home
                                  ? 'At home'
                                  : 'Location',
                          style: const TextStyle(
                              color: FlixieColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      const Text('OPTIONAL',
                          style: TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 11,
                              fontWeight: FontWeight.w800))
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _locationController,
                        style: const TextStyle(
                            color: FlixieColors.textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: FlixieColors.surfaceElevated,
                            hintText: _kind == WatchLocationKind.cinema
                                ? 'e.g. ODEON Belfast'
                                : 'e.g. My place',
                            hintStyle:
                                const TextStyle(color: FlixieColors.medium),
                            suffixIcon: const Icon(Icons.edit_outlined,
                                color: FlixieColors.primary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none))),
                    if (_kind == WatchLocationKind.cinema) ...[
                      const SizedBox(height: 14),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color:
                                  FlixieColors.secondary.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(16)),
                          child: const Text(
                              'Streaming-provider matching is switched off for this plan.',
                              style: TextStyle(
                                  color: FlixieColors.secondary, fontSize: 12)))
                    ],
                    const SizedBox(height: 20),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: FlixieColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Text(
                            'Everyone in this plan will be notified that the location changed.',
                            style: TextStyle(
                                color: FlixieColors.light, fontSize: 11))),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                            onPressed: () => Navigator.pop(
                                context, _locationController.text.trim()),
                            child: const Text('Save location',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)))),
                  ]),
            ),
          ),
        ),
      );
}

class _LocationKindOption extends StatelessWidget {
  const _LocationKindOption(
      {required this.kind,
      required this.selected,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final WatchLocationKind kind;
  final WatchLocationKind selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isSelected = kind == selected;
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                border: Border.all(
                    color: isSelected
                        ? FlixieColors.primary
                        : FlixieColors.tabBarBorder,
                    width: isSelected ? 2 : 1),
                borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: FlixieColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: FlixieColors.primary)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: FlixieColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: FlixieColors.light, fontSize: 12))
                  ])),
              Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color:
                      isSelected ? FlixieColors.primary : FlixieColors.medium)
            ])));
  }
}
