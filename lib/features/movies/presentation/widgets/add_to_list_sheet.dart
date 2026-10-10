import 'package:flutter/material.dart';
import 'add_to_list/media_list_picker.dart';

class AddToListSheet extends StatelessWidget {
  const AddToListSheet({
    super.key,
    required this.movieId,
    this.movieTitle,
    this.moviePosterPath,
    this.movieReleaseDate,
    this.movieRuntimeMinutes,
    this.movieRatingLabel,
  });

  final int movieId;
  final String? movieTitle;
  final String? moviePosterPath;
  final String? movieReleaseDate;
  final int? movieRuntimeMinutes;
  final String? movieRatingLabel;

  @override
  Widget build(BuildContext context) => MediaListPicker(mediaId: movieId);
}
