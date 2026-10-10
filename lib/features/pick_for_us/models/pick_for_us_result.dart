import 'package:flixie_app/models/movie_short.dart';

class PickForUsResult {
  final MovieShort movie;
  final int runtime;
  const PickForUsResult(this.movie, this.runtime);
  factory PickForUsResult.fromJson(Map<String, dynamic> json) =>
      PickForUsResult(
          MovieShort.fromJson(json), (json['runtime'] as num).toInt());
}

class PickForUsResponse {
  final List<PickForUsResult> choices;
  final String? message;
  const PickForUsResponse(this.choices, this.message);
}
