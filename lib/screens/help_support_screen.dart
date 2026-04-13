import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionHeader('Getting Started'),
          _FaqTile(
            question: 'What is Flixie?',
            answer:
                'Flixie is a social movie app where you can track what you\'ve watched, '
                'build a watchlist, rate movies, and invite friends to watch together.',
          ),
          _FaqTile(
            question: 'Is registration required to use Flixie?',
            answer:
                'You can browse and search for movies without creating an account. '
                'However, we highly recommend registering for a free account to unlock '
                'personalised features — create watchlists, mark content as watched, '
                'add favourites, leave reviews, connect with friends, and receive '
                'tailored recommendations. It\'s free and only takes a moment!',
          ),
          _FaqTile(
            question: 'Where does Flixie\'s data come from?',
            answer:
                'All movie details, cast and crew information, release dates, and more '
                'are sourced from The Movie Database (TMDb) — a reliable and comprehensive '
                'database dedicated to film and television. Any updates made on TMDb are '
                'reflected in Flixie to ensure you always have the most current information. '
                'Streaming availability data is powered by JustWatch, an international '
                'streaming guide used by over 20 million people per month.',
          ),
          _FaqTile(
            question: 'How frequently is content updated?',
            answer:
                'Our platform updates its data nightly, so you can count on finding the '
                'latest movies, shows, and information about casts and crews whenever you '
                'visit. It\'s like having a constantly evolving menu of entertainment at '
                'your fingertips.',
          ),
          SizedBox(height: 12),
          _SectionHeader('Watchlist, Watched & Favourites'),
          _FaqTile(
            question: 'How do I add a movie to my watchlist?',
            answer: 'Open any movie\'s detail page and tap the bookmark icon. '
                'It will be saved to your Watchlist tab so you never lose track of '
                'what to watch next.',
          ),
          _FaqTile(
            question: 'How do I mark a movie as watched?',
            answer: 'On a movie\'s detail page, tap "Mark as Watched". '
                'It will appear in your Watch History on your profile, '
                'keeping a record of your cinematic journey.',
          ),
          _FaqTile(
            question: 'How do I add a movie to my favourites?',
            answer:
                'On a movie\'s detail page, tap the heart icon. It will turn purple '
                'to confirm it\'s been added. Your favourites are displayed on your '
                'profile for easy access.',
          ),
          SizedBox(height: 12),
          _SectionHeader('Friends & Requests'),
          _FaqTile(
            question: 'How do I add a friend?',
            answer:
                'Use the Search tab to find users by username, then visit their profile '
                'and tap the "Add Friend" button.',
          ),
          _FaqTile(
            question: 'How do I invite someone to watch a movie?',
            answer: 'Open a movie\'s detail page and tap "Invite to Watch". '
                'Select a friend, add an optional message, then tap Send Invite. '
                'They\'ll see the request in their Notifications.',
          ),
          _FaqTile(
            question: 'Where do I see my sent and received watch requests?',
            answer: 'Go to your Profile and tap "Watch Requests" in the menu. '
                'You can filter by status (Pending, Accepted, Declined) and search '
                'by movie title or username.',
          ),
          SizedBox(height: 12),
          _SectionHeader('Account & Settings'),
          _FaqTile(
            question: 'How do I change my password?',
            answer: 'Go to Profile → Settings → Change Password. '
                'You\'ll need to enter your current password before setting a new one.',
          ),
          _FaqTile(
            question: 'I forgot my password — what do I do?',
            answer:
                'On the login screen, tap "Forgot Password" and enter your email. '
                'We\'ll send you a reset link.',
          ),
          _FaqTile(
            question: 'How do I sign out?',
            answer:
                'Scroll to the bottom of your Profile page and tap the "Sign Out" button.',
          ),
          SizedBox(height: 12),
          _SectionHeader('Ratings & Reviews'),
          _FaqTile(
            question: 'How do I rate a movie?',
            answer: 'Open a movie\'s detail page. After marking it as watched, '
                'you can tap the star icon to leave a rating and review.',
          ),
          _FaqTile(
            question: 'Where can I see all my reviews?',
            answer:
                'Go to Profile → My Reviews to see every movie you\'ve rated.',
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: FlixieColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Theme(
        // Remove the default divider ExpansionTile adds
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          trailing: Icon(
            _expanded ? Icons.remove : Icons.add,
            color: FlixieColors.primary,
            size: 20,
          ),
          title: Text(
            widget.question,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Text(
              widget.answer,
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
