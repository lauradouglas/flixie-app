import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'controllers/person_detail_controller.dart';
import 'person_filmography_selection.dart';
import 'widgets/person_detail/person_filmography.dart';

Future<void> togglePersonFavorite(
    BuildContext context, PersonDetailController controller) async {
  if (!await GuestAccess.require(context, title: 'Save your favourite people', path: '/people/${controller.personId}', intent: 'favorite')) return;
    if (!context.mounted) return ;
  final auth = context.read<AuthProvider>();
  bool current() =>
      context.mounted &&
      controller.active &&
      auth.dbUser?.id == controller.viewerId;
  try {
    final change = await controller.toggleFavorite();
    if (!context.mounted ||
        change == null ||
        !current() ||
        auth.dbUser?.id != change.viewerId) {
      return;
    }
    auth.updateUserList(
        favoritePeople: change.applyTo(auth.dbUser?.favoritePeople));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.success,
        content: Text(change.favorite
            ? 'Added to favourite people'
            : 'Removed from favourite people')));
  } catch (_) {
    if (!context.mounted || !current()) return;
    ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.error,
        content: const Text('Could not update favourite person.'),
        backgroundColor: context.colors.danger));
  }
}

Future<void> launchPersonLink(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> showPersonCredits(BuildContext context,
    {required List<PersonFilmCredit> credits,
    required String roleLabel,
    required void Function(int, String) onOpen}) async {
  final viewer = context.read<AuthProvider>().dbUser?.id;
  await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: .82,
          minChildSize: .45,
          maxChildSize: .95,
          expand: false,
          builder: (_, scrollController) =>
              Consumer<AuthProvider>(builder: (_, auth, __) {
                if (auth.dbUser?.id != viewer) {
                  return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Account changed'),
                        TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Close credits')),
                      ]);
                }
                return PersonCreditsSheet(
                    credits: credits,
                    library: PersonLibraryStatus.fromUser(auth.dbUser),
                    roleLabel: roleLabel,
                    scrollController: scrollController,
                    onOpen: (id, type) {
                      Navigator.of(sheetContext).pop();
                      onOpen(id, type);
                    });
              })));
}
