import 'package:cashup_pos/src/config/pos_config.dart';
import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:cashup_pos/src/ui/pages/pos_menu_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menu gates management and report entries with feature flags', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          posConfigProvider.overrideWithValue(
            PosConfig(
              baseUrl: 'https://test/',
              tokenProvider: () async => null,
              merchant: const PosMerchant(name: 'Test'),
              features: const PosFeatureFlags(
                enableProductManagement: false,
                enableCategoryManagement: false,
                enableSummaryReport: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: PosMenuPage()),
      ),
    );

    expect(find.text('Transaksi'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Produk'), findsNothing);
    expect(find.text('Kategori'), findsNothing);
    expect(find.text('Ringkasan penjualan'), findsNothing);
    expect(find.text('Segarkan katalog'), findsOneWidget);
  });
}
