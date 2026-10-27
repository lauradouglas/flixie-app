import 'package:flutter/material.dart';

class SignupSharingChoice extends StatelessWidget {
  const SignupSharingChoice(
      {super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        title: const Text('Share on Around Flixie'),
        subtitle: const Text(
            'Share your reviews, their ratings and public lists with everyone on Flixie. Your watchlist and private diary notes stay private. Change this anytime in Settings.'),
      );
}
