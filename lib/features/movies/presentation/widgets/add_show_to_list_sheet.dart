import 'package:flutter/material.dart';
import 'add_to_list/media_list_picker.dart';

class AddShowToListSheet extends StatelessWidget {
  const AddShowToListSheet({
    super.key,
    required this.showId,
    this.showTitle,
    this.showPosterPath,
    this.firstAirDate,
    this.ratingLabel,
  });

  final int showId;
  final String? showTitle;
  final String? showPosterPath;
  final String? firstAirDate;
  final String? ratingLabel;

  @override
  Widget build(BuildContext context) =>
      MediaListPicker(mediaId: showId, isShow: true);
}
