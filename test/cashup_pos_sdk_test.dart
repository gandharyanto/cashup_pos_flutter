import 'dart:async';

import 'package:cashup_pos/cashup_pos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() async => CashupPos.dispose());

  testWidgets(
    "CashupPosLauncher.open applies the host's PosTheme to the pushed page",
    (tester) async {
      const customTheme = PosTheme(
        shellBackground: Color(0xFF123456),
        surface: Color(0xFFFFFFFF),
        surfaceSoft: Color(0xFFF8FAFC),
        textOnShell: Color(0xFFFFFFFF),
        textPrimary: Color(0xFF0F172A),
        textSecondary: Color(0xFF475569),
        strokeSoft: Color(0xFFE2E8F0),
        accentSuccess: Color(0xFF10B981),
      );

      await CashupPos.initialize(
        PosConfig(
          baseUrl: 'https://example.test/',
          tokenProvider: () async => 'token',
          merchant: const PosMerchant(name: 'Toko Uji'),
          theme: customTheme,
        ),
      );

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          // The default PosTheme.cashup() has a different primary; if this
          // ever leaked through instead of CashupPos.config.theme, the
          // assertion below would fail rather than pass by coincidence.
          theme: const PosTheme.cashup().toThemeData(Brightness.light),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      unawaited(CashupPosLauncher.open(hostContext));
      await tester.pumpAndSettle();

      final pushedContext = tester.element(find.text('Pilih produk'));
      final themeOnPushedPage = Theme.of(pushedContext);

      expect(
        themeOnPushedPage.colorScheme.primary,
        customTheme.shellBackground,
      );
    },
  );
}
