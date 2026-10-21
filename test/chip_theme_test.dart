import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/theme/app_theme.dart';
import 'package:mambandamarket/theme/app_tokens.dart';

/// A selected chip (a size on the listing form, a report reason) must be
/// readable: lime fill, near-black label, in both themes.
void main() {
  for (final (name, theme) in [
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    testWidgets('$name: selected chip is lime with dark text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Row(children: [
            FilterChip(
                label: const Text('M'), selected: true, onSelected: (_) {}),
            FilterChip(
                label: const Text('L'), selected: false, onSelected: (_) {}),
          ]),
        ),
      ));
      final tokens = theme.extension<AppTokens>()!;
      Color labelColor(String t) =>
          tester.widget<RichText>(find.descendant(
                  of: find.text(t), matching: find.byType(RichText)))
              .text
              .style!
              .color!;

      expect(labelColor('M'), tokens.onAccentFill);
      expect(labelColor('L'), theme.colorScheme.onSurface);
      // Contrast of the selected label on the lime fill.
      final ratio = _contrast(tokens.onAccentFill, tokens.accentFill);
      expect(ratio, greaterThan(7));
    });
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
