import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'social/friends_sub_view.dart';
import 'social/groups_sub_view.dart';
import 'social/segmented_toggle.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  int _selectedTab = 0; // 0 = Friends, 1 = Groups

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        title: const Text(
          'Social',
          style: TextStyle(
            color: FlixieColors.light,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          SocialSegmentedToggle(
            selectedIndex: _selectedTab,
            labels: const ['Friends', 'Groups'],
            onChanged: (i) => setState(() => _selectedTab = i),
          ),
          Expanded(
            child: _selectedTab == 0
                ? const FriendsSubView()
                : const GroupsSubView(),
          ),
        ],
      ),
    );
  }
}

