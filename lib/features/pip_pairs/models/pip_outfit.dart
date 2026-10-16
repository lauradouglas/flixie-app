class PipOutfit {
  const PipOutfit(this.id, this.name, {this.extra = false});
  final String id;
  final String name;
  final bool extra;
  String get asset =>
      'assets/icon/${extra ? 'pip_pairs' : 'community_pips'}/pip-$id.png';
}

// Approved current variants only; superseded artwork stays in the design archive.
const pipOutfits = [
  PipOutfit('cowboy', 'Cowboy Pip'),
  PipOutfit('detective', 'Detective Pip'),
  PipOutfit('superhero', 'Superhero Pip'),
  PipOutfit('jedi', 'Jedi Pip'),
  PipOutfit('space-adventure', 'Space Pip'),
  PipOutfit('anime', 'Anime Pip'),
  PipOutfit('director', 'Director Pip'),
  PipOutfit('red-carpet', 'Red carpet Pip'),
  PipOutfit('black-suit', 'Black suit Pip'),
  PipOutfit('music', 'Music Pip'),
  PipOutfit('romance', 'Romance Pip'),
  PipOutfit('cosy-movie-night', 'Cosy Pip'),
  PipOutfit('interviewer', 'Interviewer Pip'),
  PipOutfit('odyssey', 'Odyssey Pip'),
  PipOutfit('vintage-soldier', 'Soldier Pip'),
  PipOutfit('horror-slasher-v2', 'Vampire Pip'),
  PipOutfit('flixie-hoodie', 'Hoodie Pip'),
  PipOutfit('laughing', 'Laughing Pip'),
  PipOutfit('stressed', 'Stressed Pip'),
  PipOutfit('sleepy', 'Sleepy Pip', extra: true),
  PipOutfit('basketball-player', 'Basketball Pip', extra: true),
  PipOutfit('dune', 'Desert Pip', extra: true),
  PipOutfit('pokemon-trainer', 'Trainer Pip', extra: true),
  PipOutfit('settings-lanyard', 'Lanyard Pip', extra: true),
];
