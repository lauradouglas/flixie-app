import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'settings_tile.dart';

class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: context.colors.danger.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kSettingsCornerRadius),
        side: BorderSide(color: context.colors.danger.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: Icon(
          Icons.delete_forever_outlined,
          color: context.colors.danger,
        ),
        title: Text(
          'Delete account',
          style: TextStyle(
            color: context.colors.danger,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          'Permanently deletes your account and Flixie data.',
          style: TextStyle(color: context.colors.medium, fontSize: 12),
        ),
        onTap: () async {
          final password = await showFlixiePromptSheet<String>(
            context: context,
            isDismissible: false,
            builder: (_) => const _DeleteAccountDialog(),
          );
          if (password == null || !context.mounted) return;

          final messenger = ScaffoldMessenger.of(context);
          final authProvider = context.read<AuthProvider>();
          final rootNavigator = Navigator.of(context, rootNavigator: true);

          showGeneralDialog<void>(
            context: context,
            barrierDismissible: false,
            barrierColor: context.colors.background,
            transitionDuration: const Duration(milliseconds: 220),
            pageBuilder: (_, __, ___) => const _AccountDeletionProgressScreen(),
            transitionBuilder: (_, animation, __, child) => FadeTransition(
              opacity: animation,
              child: child,
            ),
          );

          final error = await authProvider.deleteAccount(password);

          if (rootNavigator.mounted && rootNavigator.canPop()) {
            rootNavigator.pop();
          }
          if (error != null && messenger.mounted) {
            messenger.showFlixieToast(
              FlixieToast(
                type: FlixieToastType.error,
                content: Text(error),
              ),
            );
          }
        },
      ),
    );
  }
}

class _AccountDeletionProgressScreen extends StatelessWidget {
  const _AccountDeletionProgressScreen();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: context.colors.danger.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.danger.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 82,
                          height: 82,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: context.colors.danger,
                            backgroundColor: context.colors.tabBarBorder,
                          ),
                        ),
                        Icon(
                          Icons.shield_outlined,
                          size: 38,
                          color: context.colors.dangerTint,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Deleting your account…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We’re securely deleting your Flixie data and login. '
                    'Please keep the app open.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.light,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.tabBarBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: context.colors.success,
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            'This may take a few moments',
                            style: TextStyle(
                              color: context.colors.medium,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _hidePassword = true;

  bool get _canDelete =>
      _passwordController.text.isNotEmpty &&
      _confirmationController.text.trim() == 'DELETE';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlixiePromptSheetContent(
      title: Text(
        'Delete your account?',
        style: TextStyle(color: context.colors.white),
      ),
      content: AutofillGroup(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This cannot be undone. Your profile, reviews, ratings, '
                'watch history, lists, friendships, messages and '
                'login will be permanently deleted.',
                style: TextStyle(color: context.colors.light, height: 1.4),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _passwordController,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmationController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canDelete
              ? () => Navigator.pop(context, _passwordController.text)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
