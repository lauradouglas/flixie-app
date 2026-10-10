import '../widgets/blocked_users_sheet.dart';
import '../widgets/settings_edit_profile_sheet.dart';
import '../widgets/episode_spoiler_setting.dart';
export '../widgets/settings_edit_profile_sheet.dart'
    show showSettingsEditDetailsSheet;
import 'package:flixie_app/core/auth/social_auth_provider.dart';
import 'package:flixie_app/features/authentication/presentation/pages/social_auth_buttons.dart';
import '../widgets/around_flixie_sharing_setting.dart';
import 'package:flixie_app/features/settings/presentation/widgets/movie_rating_privacy_setting.dart';
import '../widgets/appearance_setting.dart';
import 'package:flixie_app/features/settings/presentation/widgets/delete_account_button.dart';
import 'package:flixie_app/core/legal/terms_of_use_screen.dart';
import 'package:flixie_app/features/library_import/data/library_import_session.dart';
import 'package:flixie_app/features/library_import/presentation/library_import_screen.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/features/settings/presentation/widgets/logout_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/settings/presentation/widgets/change_password_sheet.dart';
import 'package:flixie_app/features/settings/presentation/widgets/favorite_genres_sheet.dart';
import 'package:flixie_app/features/settings/presentation/widgets/settings_tile.dart';
import 'package:flixie_app/features/settings/presentation/widgets/watch_providers_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/reviews/app_review_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: context.colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (!context.select<AuthProvider, bool>(
              (auth) => auth.hasConnectedSocialProvider)) ...[
            _sectionLabel(context, 'Sign-in methods'),
            Text(
                'Connect ${SocialAuthProvider.available.map((provider) => provider.label).join(' or ')} to sign in to this same Flixie account.'),
            const SizedBox(height: 12),
            const SocialAuthButtons(connect: true),
            const SizedBox(height: 24),
          ],
          _sectionLabel(context, 'Account'),
          _SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.file_upload_outlined,
                label: 'Import ratings & watchlist',
                onTap: () async {
                  final auth = context.read<AuthProvider>();
                  final userId = auth.dbUser?.id;
                  if (userId == null) return;
                  final importController = context
                      .read<LibraryImportSession>()
                      .forUser(userId,
                          isCurrentUser: () => auth.dbUser?.id == userId);
                  await Navigator.of(context, rootNavigator: true).push<void>(
                    MaterialPageRoute(
                        builder: (_) => LibraryImportScreen(
                              controller: importController,
                            )),
                  );
                },
              ),
              SettingsTile(
                icon: Icons.person_outline,
                label: 'Edit details',
                onTap: () => _showEditProfileSheet(context),
              ),
              SettingsTile(
                icon: Icons.face_outlined,
                label: 'Change Avatar',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: context.colors.background,
                  builder: (_) => const FractionallySizedBox(
                    heightFactor: .9,
                    child: ChangeAvatarSheet(),
                  ),
                ),
              ),
              for (final provider in SocialAuthProvider.values)
                if (context.select<AuthProvider, bool>(
                    (auth) => auth.isProviderConnected(provider)))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceElevated,
                          border:
                              Border.all(color: context.colors.tabBarBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.verified_user_outlined,
                            color: FlixieColors.primary, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text('${provider.label} connected',
                              style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontWeight: FontWeight.w500))),
                      Icon(Icons.check_circle_outline,
                          color: context.colors.success, size: 20),
                    ]),
                  ),
              if (context
                  .select<AuthProvider, bool>((auth) => auth.hasPassword))
                SettingsTile(
                  icon: Icons.lock_outline,
                  label: 'Change Password',
                  onTap: () => _showChangePasswordSheet(context),
                ),
              SettingsTile(
                icon: Icons.block_outlined,
                label: 'Blocked Users',
                onTap: () => _showBlockedUsers(context),
                isLast: true,
              ),
              // TODO: implement Privacy screen
              // SettingsTile(
              //   icon: Icons.privacy_tip_outlined,
              //   label: 'Privacy',
              //   onTap: () {},
              //   isLast: true,
              // ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel(context, 'Social'),
          _SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Invite a friend',
                onTap: () => context.push('/invite-friend?from=settings'),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel(context, 'Around Flixie sharing'),
          _SettingsGroup(children: [
            AroundFlixieSharingSetting(
              key: ValueKey(context
                  .select<AuthProvider, String?>((auth) => auth.dbUser?.id)),
            )
          ]),
          const SizedBox(height: 24),
          _sectionLabel(context, 'Preferences'),
          _SettingsGroup(
            children: [
              const MovieRatingPrivacySetting(),
              const EpisodeSpoilerSetting(),
              Consumer<AnalyticsController>(
                builder: (context, analytics, _) => SettingsTile(
                  icon: Icons.analytics_outlined,
                  label: 'Share usage analytics',
                  description:
                      'Share app usage data to help us understand which features work well and improve Flixie.',
                  onTap: () => analytics.isEnabled
                      ? analytics.decline()
                      : analytics.allow(),
                  trailing: Switch.adaptive(
                    value: analytics.consent == AnalyticsConsent.accepted,
                    onChanged: (enabled) =>
                        enabled ? analytics.allow() : analytics.decline(),
                  ),
                ),
              ),
              // TODO: implement Notifications settings
              // SettingsTile(
              //   icon: Icons.notifications_outlined,
              //   label: 'Notifications',
              //   onTap: () {},
              // ),
              const AppearanceSetting(),
              SettingsTile(
                icon: Icons.live_tv_outlined,
                label: 'Watch Providers',
                onTap: () => _showWatchProvidersSheet(context),
              ),
              SettingsTile(
                icon: Icons.tune_outlined,
                label: 'Content Preferences',
                onTap: () => _showFavoriteGenresSheet(context),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel(context, 'Support'),
          _SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.explore_outlined,
                label: 'Flixie guide',
                onTap: () => context.push('/getting-started?from=settings'),
              ),
              SettingsTile(
                icon: Icons.help_outline,
                label: 'Help Center',
                onTap: () => context.push('/help-support'),
              ),
              SettingsTile(
                icon: Icons.feedback_outlined,
                label: 'Send Feedback',
                onTap: () => _sendFeedback(context),
              ),
              SettingsTile(
                icon: Icons.star_outline_rounded,
                label: 'Rate Flixie',
                onTap: () => _openStoreRating(context),
              ),
              SettingsTile(
                icon: Icons.info_outline,
                label: 'About & Credits',
                onTap: () => context.push('/about-credits'),
                isLast: true,
              ),
              SettingsTile(
                icon: Icons.description_outlined,
                label: 'Terms of Use',
                onTap: () => TermsOfUseScreen.open(context),
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => _openPrivacyPolicy(context),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const _LogOutButton(),
          const SizedBox(height: 16),
          const DeleteAccountButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.medium,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    showSettingsEditDetailsSheet(context);
  }

  Future<void> _openStoreRating(BuildContext context) async {
    final opened = await AppReviewService.openStoreListing();
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showFlixieToast(
      FlixieToast(
        type: FlixieToastType.info,
        content: const Text(
            'Ratings will be available when Flixie is in the App Store.'),
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  void _showBlockedUsers(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.background,
      builder: (_) => const FractionallySizedBox(
        heightFactor: .75,
        child: BlockedUsersSheet(),
      ),
    );
  }

  void _showFavoriteGenresSheet(BuildContext context) {
    final dbUser = context.read<AuthProvider>().dbUser;
    if (dbUser == null) return;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FavoriteGenresSheet(
          userId: dbUser.id, currentGenres: dbUser.favoriteGenres ?? []),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://www.flixie.co.uk/privacy'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Could not open the privacy policy.'),
        ),
      );
    }
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final uri =
        Uri.parse('mailto:flixieadmin@gmail.com?subject=Flixie%20Feedback');
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // A mail account or email application may not be configured.
    }
    if (!context.mounted) return;
    await showFlixiePromptSheet<void>(
      context: context,
      builder: (context) => FlixiePromptSheetContent(
        title: const Text('Contact Flixie'),
        content: const SelectableText(
          'Could not open an email app. You can copy this address and contact us from your preferred email service:\n\nflixieadmin@gmail.com',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  void _showWatchProvidersSheet(BuildContext context) {
    final dbUser = context.read<AuthProvider>().dbUser;
    if (dbUser == null) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchProvidersSheet(userId: dbUser.id),
    );
  }
}

/// Groups settings tiles into a rounded card container.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kSettingsCornerRadius),
        side: BorderSide(color: context.colors.tabBarBorder),
      ),
      child: Column(children: children),
    );
  }
}

/// Log out button shown at the bottom of Settings.
class _LogOutButton extends StatelessWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: context.colors.danger.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kSettingsCornerRadius),
        side: BorderSide(
          color: context.colors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        leading: Icon(Icons.logout_rounded, color: context.colors.danger),
        title: Text(
          'Log Out',
          style: TextStyle(
            color: context.colors.danger,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        onTap: () async {
          final auth = context.read<AuthProvider>();
          await showFlixiePromptSheet<void>(
            context: context,
            isDismissible: false,
            builder: (_) => LogoutSheet(onSignOut: auth.signOut),
          );
        },
      ),
    );
  }
}
