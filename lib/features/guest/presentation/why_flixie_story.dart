enum WhyFlixieStory {
  friends,
  providers,
  plans,
  watches,
  communities,
  television,
  extras;

  String get title => switch (this) {
        friends => 'Flixie is better\nwith friends.',
        providers => 'Saved it?\nSee where to watch.',
        plans => 'Make a plan.\nMake a night of it.',
        watches => 'Every watch\nhas its own story.',
        communities => 'Now you need\nto talk about it.',
        television => 'Your next episode.\nRight where you left it.',
        extras => 'A few extras\nto make it yours.',
      };

  String get description => switch (this) {
        friends =>
          'A friend’s favourite. A film you both want to see. Your next great watch can start with your people.',
        providers =>
          'See watch providers right in your watchlist. Filter by your subscriptions and see which saved films you can put on tonight - and which friends want to watch too.',
        plans =>
          'Use Pick for Us when you need a hand choosing. Turn your pick into a watch plan with friends, with the film and the night in one place.',
        watches =>
          'Keep the date, who you watched with, your rating and a comment in a watch entry. Watch together, keep your own opinions. Rewatch it later and keep that occasion separately.',
        communities =>
          'Join genre discussions, vote in film and TV polls, and discover titles rated by people who love the same things.',
        television =>
          'Keep track of watched episodes and see what’s next. Your film diary, TV progress, reviews, favourite rankings and taste-based recommendations all have a home.',
        extras =>
          'Rank your all-time favourites, earn badges and avatar borders, and take a break with Pip’s arcade games. A little friendly competition between films.',
      };
}
