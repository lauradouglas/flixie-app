import 'package:flutter/foundation.dart';
import 'app_review_policy.dart';
import 'dart:io';

import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Records meaningful completed actions; an idle Home gate requests reviews
/// only after sustained use. Film scores/sentiment never affect eligibility.
class AppReviewService {
  AppReviewService._();

  static const _appStoreId =
      String.fromEnvironment('FLIXIE_APP_STORE_ID', defaultValue: '6779375028');
  static final changes = ValueNotifier<int>(0);
  static String? _pendingUser;
  static bool _requesting = false;
  static Future<void>? _writes;

  static Future<void> recordCompletedWatchPlan(
    String userId, {
    required bool hasCompletedSetup,
    required String eventId,
  }) =>
      _record(userId, hasCompletedSetup, 'plan:$eventId');

  static Future<void> recordMovieInteraction(
    String userId, {
    required bool hasCompletedSetup,
    required String eventId,
  }) =>
      _record(userId, hasCompletedSetup, eventId);

  static Future<void> _record(String user, bool complete, String event) {
    if (user.isEmpty || !complete) return Future.value();
    final previous = _writes;
    late final Future<void> task;
    task = () async {
      if (previous != null) await previous;
      try {
        final preferences = await SharedPreferences.getInstance();
        await AppReviewPolicy.record(preferences, user, event, DateTime.now());
        _pendingUser = user;
        changes.value++;
      } catch (_) {
        /* Optional feedback must never fail the saved action. */
      } finally {
        if (identical(_writes, task)) _writes = null;
      }
    }();
    _writes = task;
    return task;
  }

  /// Called only after an idle pause on Home, following a successful action in
  /// this session. A cold launch, guest browse or signup never creates a request.
  static Future<void> requestIfEligible(String user,
      {required bool Function() canPrompt}) async {
    if (_requesting || _pendingUser != user || !canPrompt()) return;
    _requesting = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!AppReviewPolicy.eligible(preferences, user, DateTime.now()) ||
          !canPrompt()) {
        return;
      }
      final review = InAppReview.instance;
      if (!await review.isAvailable() || !canPrompt()) return;
      // Store quotas decide whether the native prompt is actually displayed.
      await preferences.setInt(AppReviewPolicy.globalAttemptKey,
          DateTime.now().millisecondsSinceEpoch);
      if (!canPrompt()) return;
      _pendingUser = null;
      await review.requestReview();
    } catch (_) {
      /* A review request must never interrupt app recovery. */
    } finally {
      _requesting = false;
    }
  }

  /// Opens the listing without taking the user to the review composer.
  static Future<bool> openUpdateListing() async {
    try {
      if (Platform.isIOS) {
        if (!RegExp(r'^\d+$').hasMatch(_appStoreId)) return false;
        return await launchUrl(
          Uri.https('apps.apple.com', '/app/id$_appStoreId'),
          mode: LaunchMode.externalApplication,
        );
      }
      await InAppReview.instance.openStoreListing();
      return true;
    } catch (_) {
      return false;
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
