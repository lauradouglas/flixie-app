class PipCollection {
  const PipCollection(
      {this.activePip = 'classic',
      this.cinemaUnlocked = false,
      this.ogUnlocked = false,
      this.celebrationPending = false});
  final String activePip;
  final bool cinemaUnlocked;
  final bool ogUnlocked;
  final bool celebrationPending;
  factory PipCollection.fromJson(Map<String, dynamic> json) {
    final owned = json['cinemaUnlocked'] == true;
    final og = json['ogUnlocked'] == true;
    return PipCollection(
        ogUnlocked: og,
        activePip: og && json['activePip'] == 'og'
            ? 'og'
            : owned && json['activePip'] == 'cinemaClub'
                ? 'cinemaClub'
                : 'classic',
        cinemaUnlocked: owned,
        celebrationPending: owned && json['celebrationPending'] == true);
  }
  Map<String, dynamic> toJson() => {
        'activePip': activePip,
        'cinemaUnlocked': cinemaUnlocked,
        'ogUnlocked': ogUnlocked,
        'celebrationPending': celebrationPending
      };
  static String asset(String pip) => pip == 'og'
      ? 'assets/icon/pip_cosmetics/og.png'
      : pip == 'cinemaClub'
          ? 'assets/icon/pip_cosmetics/cinema_club.png'
          : 'assets/icon/pip_cosmetics/classic.png';
  static String label(String pip) => pip == 'og'
      ? 'OG Pip'
      : pip == 'cinemaClub'
          ? 'Cinema Club Pip'
          : 'Classic Pip';
}
