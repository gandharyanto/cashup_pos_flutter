import 'package:cashup_pos/cashup_pos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(CashupPos.dispose);

  testWidgets('example renders the SDK-owned POS UI directly', (tester) async {
    const theme = PosTheme(
      shellBackground: Color(0xFF123456),
      surface: Color(0xFFFFFFFF),
      surfaceSoft: Color(0xFFF8FAFC),
      textOnShell: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF475569),
      strokeSoft: Color(0xFFE2E8F0),
      accentSuccess: Color(0xFF10B981),
    );
    await CashupPos.initialize(theme: theme);

    await tester.pumpWidget(const CashupPosApp());
    await tester.pump();

    expect(find.text('POS'), findsWidgets);
    expect(find.byTooltip('Menu POS'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(
      Theme.of(tester.element(find.byTooltip('Menu POS'))).colorScheme.primary,
      theme.shellBackground,
    );
  });
}
