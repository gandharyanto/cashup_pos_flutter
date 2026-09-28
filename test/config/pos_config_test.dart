import 'package:cashup_pos/cashup_pos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() async => CashupPos.dispose());

  test('accessing config before initialize is a clear StateError', () {
    expect(() => CashupPos.config, throwsA(isA<StateError>()));
    expect(CashupPos.isInitialized, isFalse);
  });

  test('initialize exposes the config and marks the sdk ready', () async {
    await CashupPos.initialize(
      PosConfig(
        baseUrl: 'https://example.test/',
        tokenProvider: () async => 'token',
        merchant: const PosMerchant(name: 'Toko Uji'),
      ),
    );

    expect(CashupPos.isInitialized, isTrue);
    expect(CashupPos.config.merchant.name, 'Toko Uji');
  });

  test('a trailing slash is normalised onto the base url', () async {
    await CashupPos.initialize(
      PosConfig(
        baseUrl: 'https://example.test',
        tokenProvider: () async => null,
        merchant: const PosMerchant(name: 'Toko Uji'),
      ),
    );
    expect(CashupPos.config.baseUrl, 'https://example.test/');
  });
}
