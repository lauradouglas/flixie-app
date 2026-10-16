// Fictional design preview. No account writes or real availability claims.
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';
import 'package:flixie_app/features/settings/data/availability_alert_service.dart';
import 'package:flixie_app/features/settings/presentation/widgets/availability_alert_setting.dart';

void main() => runApp(availabilityPreview());

const availabilityExamples = [
  FlixieNotification(
      id: 'demo-alien',
      userId: 'fictional',
      type: 'AVAILABILITY_ALERT',
      action: 'RECEIVED',
      read: false,
      message: 'Alien is now listed on Netflix in GB.',
      data: {
        'mediaType': 'movie',
        'mediaTitle': 'Alien',
        'providerNames': 'Netflix',
        'country': 'GB',
        'posterPath': '/vfrQk5IPloGg1v9Rzbh2Eg3VGyM.jpg',
        'route': '/movies/348?source=notification'
      }),
  FlixieNotification(
      id: 'demo-newsroom',
      userId: 'fictional',
      type: 'AVAILABILITY_ALERT',
      action: 'RECEIVED',
      read: false,
      message: 'The Newsroom is now listed on Netflix in GB.',
      data: {
        'mediaType': 'tv',
        'mediaTitle': 'The Newsroom',
        'providerNames': 'Netflix',
        'country': 'GB',
        'posterPath': '/2s6IPLtfw0GiMxlJznb1TkA6KXk.jpg',
        'route': '/shows/15621?source=notification'
      }),
];

@Preview(name: 'Availability alerts · phone', size: Size(390, 844))
@Preview(name: 'Availability alerts · tablet', size: Size(1100, 820))
Widget availabilityPreview() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme,
    home: const AvailabilityPreviewScreen());

class AvailabilityPreviewScreen extends StatelessWidget {
  const AvailabilityPreviewScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final inbox =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Notifications',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('New from your watchlist',
              style: TextStyle(color: context.colors.light)),
          for (final n in availabilityExamples) ...[
            NotificationInboxCard(
                notification: n,
                date: 'Today',
                onOptions: () => _options(context),
                onOpen: () => _open(context, n)),
            Divider(height: 1, color: context.colors.tabBarBorder),
          ],
          const SizedBox(height: 26),
          Text('Phone notification preview',
              style: TextStyle(color: context.colors.light, fontSize: 13)),
          const SizedBox(height: 10),
          Material(
              color: context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.asset(
                                'assets/icon/flixie_icon_1024.png',
                                width: 32,
                                height: 32)),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                FlixieWordmark(fontSize: 15),
                                Spacer(),
                                Text('now', style: TextStyle(fontSize: 11))
                              ]),
                              SizedBox(height: 8),
                              Text('Now on your services',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                              SizedBox(height: 4),
                              Text('Alien is now listed on Netflix in GB.',
                                  style: TextStyle(height: 1.4)),
                            ])),
                      ]))),
        ]);
        final settings =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Availability alerts',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Material(
              color: context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              child: AvailabilityAlertSetting(
                  userId: 'fictional',
                  showPushChoice: false,
                  load: () async => const AvailabilityAlertSettings(
                      enabled: true,
                      countryName: 'United Kingdom',
                      services: ['Netflix']),
                  save: (value) async => AvailabilityAlertSettings(
                      enabled: value,
                      countryName: 'United Kingdom',
                      services: const ['Netflix']))),
        ]);
        return SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 32 : 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FlixieWordmark(fontSize: 26),
              const SizedBox(height: 12),
              Text('Mockup · fictional availability',
                  style: TextStyle(color: context.colors.light, fontSize: 12)),
              const SizedBox(height: 24),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: inbox),
                  const SizedBox(width: 40),
                  Expanded(flex: 2, child: settings)
                ])
              else
                inbox,
              if (!wide) ...[const SizedBox(height: 32), settings],
            ]));
      })));

  void _open(BuildContext context, FlixieNotification n) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (context) => Scaffold(
              appBar: AppBar(title: Text(n.watchMediaTitle!)),
              body: const Center(child: Text('Preview title destination')))));
  void _options(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
          child: ListTile(
              title: const Text('Dismiss preview'),
              onTap: () => Navigator.pop(context))));
}
