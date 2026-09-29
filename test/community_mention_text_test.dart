import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_mention_text.dart';

void main() {
  testWidgets('mentions are purple while prose and email remain unchanged',
      (tester) async {
    const text = '@dev_actor yea. Email a@b.com or ask @another.name!';
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(body: CommunityMentionText(text)),
    ));
    final selectable =
        tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.textSpan!.toPlainText(), text);
    final spans = selectable.textSpan!.children!.cast<TextSpan>();
    final colored = spans.where((span) => span.style?.color != null).toList();
    expect(colored.map((span) => span.text), ['@dev_actor', '@another.name']);
    final context = tester.element(find.byType(CommunityMentionText));
    expect(
        colored
            .every((span) => span.style!.color == context.colors.primaryText),
        isTrue);
  });
}
