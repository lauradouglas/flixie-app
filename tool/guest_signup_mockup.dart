// Design mockup only: no authentication, network or production route changes.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';

final guestPipImage = MemoryImage(File('design/merch/pip/transparent/pip-3d-glasses.png').readAsBytesSync());

class GuestSignupMockup extends StatelessWidget {
  const GuestSignupMockup({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
            backgroundColor: colors.background,
            title: Text.rich(flixieWordmarkSpan(fontSize: 24, fontFamily: 'Manrope', foregroundColor: colors.white)),
            actions: [
              TextButton(onPressed: () {}, child: const Text('Sign in'))
            ]),
        bottomNavigationBar:
            NavigationBar(selectedIndex: 0, destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.explore_outlined), label: 'Discover'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), label: 'Plans'),
          NavigationDestination(
              icon: Icon(Icons.people_outline), label: 'Social'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ]),
        body: SingleChildScrollView(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                        child: Text('Make it your\nmovie life.',
                                            style: TextStyle(
                                                fontSize: 32,
                                                height: 1.12,
                                                fontWeight: FontWeight.w800,
                                                color: colors.white))),
                                    const SizedBox(width: 8),
                                    Image(image: guestPipImage,
                                        width: 120,
                                        height: 145,
                                        fit: BoxFit.contain),
                                  ]),
                              const SizedBox(height: 10),
                              Text(
                                  'Found something you love?\nGive it a home on Flixie.',
                                  style: TextStyle(
                                      fontSize: 17,
                                      height: 1.5,
                                      color: colors.medium)),
                              const SizedBox(height: 28),
                              for (final benefit in [
                                (
                                  Icons.bookmark_border,
                                  'Keep your next watch close',
                                  'Save films and shows to your watchlist.'
                                ),
                                (
                                  Icons.star_border,
                                  'Remember the good ones',
                                  'Rate what you watch and track your favourites.'
                                ),
                                (
                                  Icons.people_outline,
                                  'Find your film people',
                                  'Share opinions and plan a watch with friends.'
                                ),
                              ])
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(benefit.$1,
                                              size: 25, color: colors.primary),
                                          const SizedBox(width: 14),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(benefit.$2,
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: colors.white)),
                                                const SizedBox(height: 4),
                                                Text(benefit.$3,
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        height: 1.45,
                                                        color: colors.medium)),
                                              ])),
                                        ])),
                              SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                      style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          backgroundColor: colors.primary),
                                      onPressed: () {},
                                      child: const Text('Create account',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700)))),
                              const SizedBox(height: 10),
                              Center(
                                  child: Text(
                                      'You can keep exploring without an account.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          color: colors.medium))),
                              const SizedBox(height: 30),
                              const Divider(height: 1),
                              const SizedBox(height: 24),
                              Text('Find your next great watch',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: colors.white)),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.search),
                                  label: const Text('Search movies and shows')),
                              const SizedBox(height: 14),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final genre in [
                                  'Action',
                                  'Romance',
                                  'Anime',
                                  'Horror'
                                ])
                                  ActionChip(
                                      label: Text(genre), onPressed: () {})
                              ]),
                            ]))))));
  }
}
