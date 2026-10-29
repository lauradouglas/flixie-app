import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

/// A fictional saved-service match, not live availability or the visitor's data.
class GuestProviderExample extends StatelessWidget {
  const GuestProviderExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Text copy(String value,
            {double size = 14, bool bold = false, Color? color}) =>
        Text(value,
            style: TextStyle(
                fontSize: size,
                height: 1.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: color ?? colors.white));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Find where to watch.',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      copy('See what’s on your services, plus rental and purchase options.'),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: colors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
                padding: EdgeInsets.all(4),
                child: ProfileAvatarView(
                    avatar: null,
                    fallbackText: 'M',
                    fallbackColor: Color(0xFF7043AD),
                    size: 28,
                    profileBadges: ['EARLY_ADOPTER'])),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  copy('Maya’s services', size: 13, bold: true),
                  copy('HBO Max', size: 11, color: colors.light),
                ])),
            const SizedBox(width: 8),
            copy('Example', size: 11, color: colors.light),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                    'assets/images/guest-provider-dark-knight.jpg',
                    width: 84,
                    height: 126,
                    fit: BoxFit.contain,
                    semanticLabel: 'The Dark Knight poster')),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  copy('The Dark Knight', size: 15, bold: true),
                  copy('2008', size: 11, color: colors.light),
                ])),
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final label in ['Stream 1', 'Rent 5', 'Buy 5'])
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 2),
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  width: label == 'Stream 1' ? 2 : 1,
                                  color: label == 'Stream 1'
                                      ? colors.primaryText
                                      : colors.tabBarBorder))),
                      child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: label.split(' ').first,
                                style: TextStyle(
                                    fontWeight: label == 'Stream 1'
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                            TextSpan(
                                text: '  ${label.split(' ').last}',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w400)),
                          ]),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              color: label == 'Stream 1'
                                  ? colors.primaryText
                                  : colors.light)))),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: const Color(0xFF351279),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('HBO\nmax',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  copy('HBO Max', size: 13, bold: true),
                  copy('Subscription required', size: 11, color: colors.light),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check_circle,
                        size: 15, color: Color(0xFF93EAC5)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: copy('Your service',
                            size: 11, color: const Color(0xFF93EAC5))),
                  ]),
                ])),
            const SizedBox(width: 8),
            ExcludeSemantics(
                child: Icon(Icons.open_in_new,
                    size: 20, color: colors.primaryText)),
          ]),
        ]),
      ),
      const SizedBox(height: 8),
      copy('Illustrative example. Availability depends on your country.',
          size: 11, color: colors.light),
      const SizedBox(height: 8),
      copy('Find it in Flixie. Watch on the provider’s app.', size: 12),
    ]);
  }
}
