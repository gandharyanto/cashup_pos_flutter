// test/public_api_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no source file outside lib/src imports lib/src by package path', () {
    final offenders = <String>[];
    for (final entity in Directory('example/lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      if (content.contains('package:cashup_pos/src/')) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'the example must consume only the public surface',
    );
  });

  test('every public symbol the README documents is exported', () {
    final exports = File('lib/cashup_pos.dart').readAsStringSync();
    for (final symbol in const [
      'CashupPos',
      'CashupPosLauncher',
      'PosConfig',
      'PosMerchant',
      'PosFeatureFlags',
      'PosTheme',
      'PosPaymentHandler',
      'PosPaymentResult',
      'QrisGateway',
      'QrisPayload',
      'QrisStatus',
      'PosException',
      'PosErrorKind',
    ]) {
      expect(
        exports.contains(symbol),
        isTrue,
        reason: '$symbol is not exported',
      );
    }
  });
}
