import '../../../watchlist/data/guest_watchlist_store.dart';
import '../../../authentication/data/setup_service.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/signup_title_context.dart';
import 'package:flixie_app/features/authentication/models/signup_journey.dart';
import 'package:flutter/material.dart';
import '../guest_access.dart';

/// The guest's selected title stays visible while creating their account.
class BookmarkSignupContext extends StatelessWidget {
  const BookmarkSignupContext({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SignupJourney.supports(GuestAccess.action, GuestAccess.destination)) {
      return const SizedBox.shrink();
    }
    if (GuestAccess.action == 'guest-watchlist') {
      return FutureBuilder<List<SetupTitle>>(
          future: GuestWatchlistStore.instance.read(),
          builder: (context, snapshot) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Keep your picks',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                        'We’ll save your device picks to your account before any optional setup.'),
                    for (final pick in snapshot.data?.take(3) ?? <SetupTitle>[])
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SignupTitleContext(
                              title: pick.name,
                              isShow: pick.isShow,
                              poster: pick.poster)),
                    if ((snapshot.data?.length ?? 0) > 3)
                      Text(
                          'And ${snapshot.data!.length - 3} more picks - we’ll keep them all.'),
                  ])));
    }
    if (GuestAccess.action == 'home' || GuestAccess.action == 'profile') {
      return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(GuestAccess.action == 'profile'
              ? 'Your favourites, diary and opinions - all in one profile.'
              : 'After signup, choose your first watchlist pick, favourite or diary entry.'));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (RegExp(r'^/(movies|shows)/[0-9]+$')
            .hasMatch(GuestAccess.destination ?? ''))
          SignupTitleContext(
              title: GuestAccess.bookmarkTitle ?? 'Your chosen title',
              isShow: GuestAccess.destination?.startsWith('/shows/') == true,
              poster: GuestAccess.poster),
        Text(
            '${GuestAccess.action == 'watchlist' ? 'Your first save' : GuestAccess.action == 'rate' ? 'Your first rating' : GuestAccess.action == 'review' ? 'Your first review' : GuestAccess.action == 'favorite' ? 'Your favourite' : 'Your first watch'}: ${GuestAccess.bookmarkTitle ?? 'your chosen title'}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(GuestAccess.action == 'watchlist'
            ? 'We’ll save it after you create your account. You can personalise Flixie afterwards.'
            : 'Create your account, then pick up right here. Personalise Flixie afterwards.'),
      ]),
    );
  }
}
