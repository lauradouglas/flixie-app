class UnlockedPip {
  const UnlockedPip(this.key, {this.celebrationPending = false});
  final String key;
  final bool celebrationPending;
  Map<String, dynamic> toJson() =>
      {'key': key, 'celebrationPending': celebrationPending};
}

class PipCollection {
  const PipCollection(
      {this.activePip = 'classic',
      this.cinemaUnlocked = false,
      this.ogUnlocked = false,
      this.celebrationPending = false,
      this.unlockedPips = const []});
  final List<UnlockedPip> unlockedPips;
  bool owns(String pip) =>
      pip == 'classic' ||
      (pip == 'og' && ogUnlocked) ||
      (pip == 'cinemaClub' && cinemaUnlocked) ||
      unlockedPips.any((owned) => owned.key == pip);
  static bool supportedSeasonal(String pip) => pip == 'christmasLights';
  final String activePip;
  final bool cinemaUnlocked;
  final bool ogUnlocked;
  final bool celebrationPending;
  factory PipCollection.fromJson(Map<String, dynamic> json) {
    final owned = json['cinemaUnlocked'] == true;
    final og = json['ogUnlocked'] == true;
    final seasonal = (json['unlockedPips'] as List? ?? [])
        .whereType<Map>()
        .where((row) =>
            row['key'] is String && supportedSeasonal(row['key'] as String))
        .map((row) => UnlockedPip(row['key'] as String,
            celebrationPending: row['celebrationPending'] == true))
        .toList();
    return PipCollection(
        ogUnlocked: og,
        unlockedPips: seasonal,
        activePip: og && json['activePip'] == 'og'
            ? 'og'
            : owned && json['activePip'] == 'cinemaClub'
                ? 'cinemaClub'
                : seasonal.any((pip) => pip.key == json['activePip'])
                    ? json['activePip'] as String
                    : 'classic',
        cinemaUnlocked: owned,
        celebrationPending: owned && json['celebrationPending'] == true);
  }
  Map<String, dynamic> toJson() => {
        'activePip': activePip,
        'cinemaUnlocked': cinemaUnlocked,
        'ogUnlocked': ogUnlocked,
        'celebrationPending': celebrationPending,
        'unlockedPips': unlockedPips.map((pip) => pip.toJson()).toList()
      };
  static String asset(String pip) => pip == 'christmasLights'
      ? 'assets/icon/pip_cosmetics/christmas_lights.png'
      : pip == 'og'
          ? 'assets/icon/pip_cosmetics/og.png'
          : pip == 'cinemaClub'
              ? 'assets/icon/pip_cosmetics/cinema_club.png'
              : 'assets/icon/pip_cosmetics/classic.png';
  static String label(String pip) => pip == 'christmasLights'
      ? 'Christmas Pip'
      : pip == 'og'
          ? 'OG Pip'
          : pip == 'cinemaClub'
              ? 'Cinema Club Pip'
              : 'Classic Pip';
}
