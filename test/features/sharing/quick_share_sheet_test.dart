import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/sharing/presentation/quick_share_sheet.dart';

void main() {
  testWidgets('Story steps copy the referral and save independently', (t) async {
    var copies = 0;
    var saves = 0;
    await t.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body:
      QuickShareSheet(saveCard: () async { saves++; }, copyReferralLink: () async { copies++; }))));
    await t.tap(find.text('Post to your Story'));
    await t.pumpAndSettle();
    expect(find.text('Finish in Instagram'), findsOneWidget);
    await t.tap(find.text('Copy referral link'));
    await t.pumpAndSettle();
    expect(copies, 1);
    expect(saves, 0);
    expect(find.text('Referral link copied'), findsOneWidget);
    await t.tap(find.text('Save card to Photos'));
    await t.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Saved to Photos'), findsOneWidget);
  });
  testWidgets('failed copy stays retryable without claiming success', (t) async {
    await t.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body:
      QuickShareSheet(saveCard: () async {}, copyReferralLink: () async { throw StateError('Try again'); }))));
    await t.tap(find.text('Post to your Story'));
    await t.pumpAndSettle();
    await t.tap(find.text('Copy referral link'));
    await t.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Referral link copied'), findsNothing);
    expect(t.widget<ListTile>(find.widgetWithText(ListTile, 'Copy referral link')).enabled, isTrue);
  });
  testWidgets('friends option returns native-share selection', (t) async {
    bool? result;
    await t.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body:
      Builder(builder: (context) => TextButton(onPressed: () async {
        result = await showQuickShareSheet(context, saveCard: () async {}, copyReferralLink: () async {});
      }, child: const Text('Open'))))));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Send to friends'));
    await t.pumpAndSettle();
    expect(result, true);
  });
}
