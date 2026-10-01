import 'package:flutter/material.dart';

/// One scroll position for the profile header and all its tab contents.
class ProfileScrollView extends StatelessWidget {
  const ProfileScrollView({super.key, required this.slivers});
  final List<Widget> slivers;
  @override
  Widget build(BuildContext context) => CustomScrollView(
        key: const PageStorageKey('profile-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      );
}
