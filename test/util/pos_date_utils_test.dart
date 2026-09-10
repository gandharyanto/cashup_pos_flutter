import 'package:cashup_pos/src/util/pos_date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parse', () {
    test('parses every shape the backend emits', () {
      for (final raw in const [
        '2026-09-10T14:05:03',
        '2026-09-10T14:05:03Z',
        '2026-09-10 14:05:03',
        '2026-09-10T14:05:03.123',
        '2026-09-10T14:05:03.123Z',
      ]) {
        final parsed = PosDates.parse(raw);
        expect(parsed, isNotNull, reason: raw);
        expect(parsed!.year, 2026, reason: raw);
        expect(parsed.month, 9, reason: raw);
        expect(parsed.day, 10, reason: raw);
        expect(parsed.hour, 14, reason: raw);
        expect(parsed.minute, 5, reason: raw);
        expect(parsed.second, 3, reason: raw);
      }
    });

    test('treats a trailing Z as a literal, not a timezone', () {
      // The Kotlin original quotes Z in its SimpleDateFormat pattern, so the
      // wall-clock fields are taken as-is. DateTime.parse would instead read
      // UTC and shift the receipt time by the device offset (+7 in WIB).
      final parsed = PosDates.parse('2026-09-10T14:05:03Z')!;
      expect(parsed.isUtc, isFalse);
      expect(parsed.hour, 14);
    });

    test('parses a date-only value used by the range filters', () {
      final parsed = PosDates.parse('2026-09-10');
      expect(parsed, isNotNull);
      expect(parsed!.day, 10);
      expect(parsed.hour, 0);
    });

    test('returns null rather than throwing on junk', () {
      expect(PosDates.parse('not a date'), isNull);
      expect(PosDates.parse(''), isNull);
      expect(PosDates.parse(null), isNull);
    });
  });

  group('display', () {
    test('uses Indonesian month abbreviations', () {
      expect(PosDates.display(DateTime(2026, 9, 10)), '10 Sep 2026');
      expect(PosDates.display(DateTime(2026, 5, 1)), '01 Mei 2026');
      expect(PosDates.display(DateTime(2026, 8, 31)), '31 Agu 2026');
      expect(PosDates.display(DateTime(2026, 12, 25)), '25 Des 2026');
    });

    test('renders time zero-padded to seconds', () {
      expect(PosDates.time(DateTime(2026, 9, 10, 9, 5, 3)), '09:05:03');
    });

    test('formats api parameters as plain ISO dates', () {
      expect(PosDates.apiDate(DateTime(2026, 9, 10)), '2026-09-10');
      expect(
        PosDates.apiDateTime(DateTime(2026, 9, 10, 14, 5, 3)),
        '2026-09-10T14:05:03',
      );
    });
  });

  group('displayRaw', () {
    test('renders a parsed value as date and time', () {
      expect(
        PosDates.displayRaw('2026-09-10T14:05:03'),
        '10 Sep 2026 14:05:03',
      );
    });

    test('falls back to a dash when the value cannot be parsed', () {
      expect(PosDates.displayRaw('garbage'), '-');
      expect(PosDates.displayRaw(null), '-');
    });
  });
}
