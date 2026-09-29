import 'package:cashup_pos/cashup_pos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() async => CashupPos.dispose());

  test('accessing config before initialize is a clear StateError', () {
    expect(() => CashupPos.config, throwsA(isA<StateError>()));
    expect(CashupPos.isInitialized, isFalse);
  });

  test('initializeWithConfig exposes config and marks sdk ready', () async {
    await CashupPos.initializeWithConfig(
      PosConfig(
        baseUrl: 'https://example.test/',
        tokenProvider: () async => 'token',
        merchant: const PosMerchant(name: 'Toko Uji'),
      ),
    );

    expect(CashupPos.isInitialized, isTrue);
    expect(CashupPos.config.merchant.name, 'Toko Uji');
  });

  test('simple initialize accepts theme and catalogue banner urls', () async {
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

    const banners = [
      'https://cdn.example.test/banner-1.jpg',
      'https://cdn.example.test/banner-2.jpg',
    ];
    await CashupPos.initialize(theme: theme, bannerImageUrls: banners);

    expect(CashupPos.config.theme, same(theme));
    expect(CashupPos.config.merchant.name, 'Toko Demo Cashup');
    expect(CashupPos.config.bannerImageUrls, banners);
  });

  test('a trailing slash is normalised onto the base url', () async {
    await CashupPos.initializeWithConfig(
      PosConfig(
        baseUrl: 'https://example.test',
        tokenProvider: () async => null,
        merchant: const PosMerchant(name: 'Toko Uji'),
        bannerImageUrls: const ['https://cdn.example.test/banner.jpg'],
      ),
    );
    expect(CashupPos.config.baseUrl, 'https://example.test/');
    expect(CashupPos.config.bannerImageUrls, hasLength(1));
  });
}
