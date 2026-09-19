import 'dart:io';

import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Requests a native Store review after an onboarding-complete user reaches a
/// positive Watch Plan or movie-engagement milestone. Store quotas remain the
/// final authority.
class AppReviewService {
  AppReviewService._();

  static const _completedPlansPrefix = 'app_review.completed_plans.';
  static const _movieInteractionsPrefix = 'app_review.movie_interactions.';
  static const _lastPromptPrefix = 'app_review.last_prompt.';
  static const _minimumCompletedPlans = 1;
  static const _minimumMovieInteractions = 3;
  static const _cooldown = Duration(days: 120);
  static const _appStoreId =
      String.fromEnvironment('FLIXIE_APP_STORE_ID', defaultValue: '6779375028');

  static Future<void> recordCompletedWatchPlan(
    String userId, {
    required bool hasCompletedSetup,
  }) async {
    if (userId.isEmpty || !hasCompletedSetup) return;
    final preferences = await SharedPreferences.getInstance();
    final completedKey = '$_completedPlansPrefix$userId';
    final completedPlans = (preferences.getInt(completedKey) ?? 0) + 1;
    await preferences.setInt(completedKey, completedPlans);

    if (completedPlans < _minimumCompletedPlans) return;
    await _tryRequestReview(preferences, userId);
  }

  static Future<void> recordMovieInteraction(
    String userId, {
    required bool hasCompletedSetup,
  }) async {
    if (userId.isEmpty || !hasCompletedSetup) return;
    final preferences = await SharedPreferences.getInstance();
    final interactionKey = '$_movieInteractionsPrefix$userId';
    final interactions = (preferences.getInt(interactionKey) ?? 0) + 1;
    await preferences.setInt(interactionKey, interactions);
    if (interactions < _minimumMovieInteractions) return;
    await _tryRequestReview(preferences, userId);
  }

  static Future<void> _tryRequestReview(
    SharedPreferences preferences,
    String userId,
  ) async {
    final lastPromptMs = preferences.getInt('$_lastPromptPrefix$userId');
    if (lastPromptMs != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(lastPromptMs),
            ) <
            _cooldown) {
      return;
    }

    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      // Record the attempt as platform quotas may decide not to show a prompt.
      await preferences.setInt(
        '$_lastPromptPrefix$userId',
        DateTime.now().millisecondsSinceEpoch,
      );
      await review.requestReview();
    } catch (_) {
      // A review prompt is always optional and must never disrupt the watch.
    }
  }

  /// The Settings action deliberately opens the store listing rather than
  /// requesting the quota-limited native prompt.
  static Future<bool> openStoreListing() async {
    if (Platform.isIOS && !RegExp(r'^\d+$').hasMatch(_appStoreId)) return false;
    try {
      if (Platform.isIOS) {
        // HTTPS can fall back to the web when the App Store is unavailable,
        // including in the simulator; custom store schemes cannot.
        return await launchUrl(
          Uri.https('apps.apple.com', '/app/id$_appStoreId',
              {'action': 'write-review'}),
          mode: LaunchMode.externalApplication,
        );
      }
      await InAppReview.instance.openStoreListing(
        appStoreId: Platform.isIOS ? _appStoreId : null,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
