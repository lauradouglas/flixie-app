import 'widgets/cinema_account_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// A single explicit guest action, retained only for the current app session.
class GuestAccess {
  static String? destination;
  static String? action;
  static bool awaitingAccount = false;
  static void clear() {
    destination = null;
    action = null;
    awaitingAccount = false;
  }

  static String? takeAction(String path) {
    if (destination != path) return null;
    final value = action;
    clear();
    return value;
  }

  static bool isPublicPath(String path) =>
      [
        '/',
        '/search',
        '/profile',
        '/welcome',
        '/help-support',
        '/about-credits'
      ].contains(path) ||
      RegExp(r'^/(movies|shows|people|collections)/[0-9]+$').hasMatch(path);

  static Future<bool> require(
    BuildContext context, {
    String title = 'Make Flixie yours',
    String message =
        'Create an account to save your favourites and connect with others.',
    String? path,
    String? intent,
  }) async {
    if (context.read<AuthProvider>().dbUser != null) return true;
    final target = path ?? GoRouterState.of(context).uri.toString();
    final choice = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: context.colors.background,
        builder: (sheet) => CinemaAccountSheet(
              title: title,
              message: message,
              showReturnNote: intent != null,
              onChoice: (choice) => Navigator.pop(sheet, choice),
            ));
    if (choice != null && context.mounted) {
      destination = isPublicPath(Uri.parse(target).path)
          ? Uri.parse(target).path
          : target;
      action = intent;
      awaitingAccount = true;
      context.go('/auth/$choice');
    }
    return false;
  }
}
