/// Device-local work. A null watch date means unknown, never today.
class GuestDiaryDraft {
  const GuestDiaryDraft(
      {required this.id,
      required this.movieId,
      required this.title,
      this.poster,
      this.watchInviteToken,
      this.watchRequestId,
      this.inviterName,
      this.referralCode,
      this.connectInviter = false,
      this.logWatch = true,
      this.rating,
      this.date = '',
      this.note = '',
      this.recommended,
      this.owner,
      this.submitted = false});
  final String id, title, date, note;
  final int movieId;
  final String? poster,
      owner,
      watchInviteToken,
      inviterName,
      referralCode,
      watchRequestId;
  final bool connectInviter;
  final bool logWatch;
  final bool submitted;
  final int? rating;
  final bool? recommended;
  GuestDiaryDraft withOwner(String user) => GuestDiaryDraft(
      id: id,
      movieId: movieId,
      title: title,
      poster: poster,
      watchInviteToken: watchInviteToken,
      watchRequestId: watchRequestId,
      inviterName: inviterName,
      referralCode: referralCode,
      connectInviter: connectInviter,
      logWatch: logWatch,
      rating: rating,
      date: date,
      note: note,
      recommended: recommended,
      owner: user,
      submitted: submitted);
  Map<String, dynamic> toJson() => {
        'id': id,
        'movieId': movieId,
        'title': title,
        'poster': poster,
        'watchInviteToken': watchInviteToken,
        'watchRequestId': watchRequestId,
        'inviterName': inviterName,
        'referralCode': referralCode,
        'connectInviter': connectInviter,
        'logWatch': logWatch,
        'rating': rating,
        'date': date,
        'note': note,
        'recommended': recommended,
        'owner': owner,
        'submitted': submitted
      };
  factory GuestDiaryDraft.fromJson(Map<String, dynamic> j) => GuestDiaryDraft(
      id: j['id'] as String,
      movieId: j['movieId'] as int,
      title: j['title'] as String,
      poster: j['poster'] as String?,
      watchInviteToken: j['watchInviteToken'] as String?,
      watchRequestId: j['watchRequestId'] as String?,
      inviterName: j['inviterName'] as String?,
      referralCode: j['referralCode'] as String?,
      connectInviter: j['connectInviter'] == true,
      logWatch: j['logWatch'] as bool,
      rating: j['rating'] as int?,
      date: j['date'] as String,
      note: j['note'] as String,
      recommended: j['recommended'] as bool?,
      owner: j['owner'] as String?,
      submitted: j['submitted'] == true);
  String? validate() {
    if (rating != null && (rating! < 1 || rating! > 10)) {
      return 'Choose a score from 1 to 10.';
    }
    if (!logWatch && rating == null) {
      return 'Choose a score to save your rating.';
    }
    if (date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          parsed == null ||
          parsed.toIso8601String().substring(0, 10) != date ||
          parsed.isAfter(DateTime.now())) {
        return 'Enter a real watch date as YYYY-MM-DD, no later than today.';
      }
    }
    if (note.length > 2000) return 'Keep your note within 2,000 characters.';
    return null;
  }
}
