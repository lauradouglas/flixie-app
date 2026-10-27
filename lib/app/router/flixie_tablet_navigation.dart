import 'package:flixie_app/features/pip/presentation/widgets/pip_companion.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';

const flixieTabletNavigationBreakpoint = 1000.0;
const flixieDestinationPaths = [
  '/',
  '/search',
  '/plans',
  '/social',
  '/profile'
];

/// Tablet counterpart of the retained phone tabs, plus a library shortcut.
class FlixieTabletNavigation extends StatelessWidget {
  const FlixieTabletNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onWatchlist,
    this.watchlistSelected = false,
    this.guest = false,
    this.unreadMessages = 0,
  });
  final int selectedIndex, unreadMessages;
  final ValueChanged<int> onSelected;
  final VoidCallback onWatchlist;
  final bool watchlistSelected, guest;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 184 : 156,
        child: Material(
          color: context.colors.tabBarBackground,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 0, 16),
                  child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FlixieWordmark(fontSize: 26),
                        PipHeaderCompanion()
                      ]),
                ),
                for (final index in guest ? [0, 1, 4] : [0, 1, 2, 3, 4])
                  _destination(
                    context,
                    label: [
                      'Home',
                      'Discover',
                      'Plans',
                      'Social',
                      guest ? 'You' : 'Profile'
                    ][index],
                    icon: [
                      Icons.home_outlined,
                      Icons.explore_outlined,
                      Icons.event_outlined,
                      Icons.people_outline,
                      Icons.person_outline
                    ][index],
                    selected: !watchlistSelected && selectedIndex == index,
                    unread: index == 3 ? unreadMessages : 0,
                    onTap: () => onSelected(index),
                  ),
                if (!guest) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child:
                        Divider(height: 1, color: context.colors.tabBarBorder),
                  ),
                  _destination(context,
                      label: 'Watchlist',
                      icon: Icons.bookmark_outline,
                      selected: watchlistSelected,
                      onTap: onWatchlist),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _destination(BuildContext context,
          {required String label,
          required IconData icon,
          required bool selected,
          required VoidCallback onTap,
          int unread = 0}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Semantics(
          selected: selected,
          button: true,
          onTap: onTap,
          label: unread > 0 ? '$label, $unread unread messages' : label,
          excludeSemantics: true,
          child: ListTile(
            key: ValueKey('tablet-nav-${label.toLowerCase()}'),
            onTap: onTap,
            minTileHeight: 52,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            horizontalTitleGap: 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: selected ? context.colors.primary : Colors.transparent,
            leading: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: FlixieColors.notificationBadge,
              child: Icon(icon,
                  color: selected ? Colors.white : context.colors.light),
            ),
            title: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : context.colors.light,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ),
        ),
      );
}

/// Root detail routes keep tablet navigation while retaining phone back routes.
class FlixieTabletRouteFrame extends StatefulWidget {
  const FlixieTabletRouteFrame(
      {super.key, required this.child, this.watchlist = false});
  final Widget child;
  final bool watchlist;

  @override
  State<FlixieTabletRouteFrame> createState() => _FlixieTabletRouteFrameState();
}

class _FlixieTabletRouteFrameState extends State<FlixieTabletRouteFrame> {
  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final content = KeyedSubtree(key: _contentKey, child: widget.child);
        if (constraints.maxWidth < flixieTabletNavigationBreakpoint) {
          return content;
        }
        return ColoredBox(
          color: context.colors.background,
          child: Row(children: [
            FlixieTabletNavigation(
              selectedIndex: -1,
              watchlistSelected: widget.watchlist,
              guest: context
                  .select<AuthProvider, bool>((auth) => auth.dbUser == null),
              unreadMessages:
                  context.watch<ChatUnreadController?>()?.total ?? 0,
              onSelected: (index) => context.go(flixieDestinationPaths[index]),
              onWatchlist: () {
                if (!widget.watchlist) context.push('/watchlist');
              },
            ),
            Expanded(
                child: SafeArea(
                    top: false, bottom: false, left: false, child: content)),
          ]),
        );
      });
}
