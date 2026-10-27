enum RatingCardStyle {
  posterSticker('Poster sticker'),
  cinemaTicket('Compact poster'),
  pocketTicket('Pocket ticket'),
  polaroid('Polaroid'),
  circleStamp('Circle stamp'),
  fullStory('Full Story');

  const RatingCardStyle(this.label);
  final String label;
}

enum RatingCardBackground {
  transparent('Transparent'),
  dark('Black'),
  lilac('Lilac'),
  bone('Bone');

  const RatingCardBackground(this.label);
  final String label;
}
