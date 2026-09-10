/// Date parsing and display for the SDK.
///
/// The backend emits the same field in five shapes — the Kotlin
/// `ReceiptTemplate` walks the same list before giving up:
///
/// ```text
/// 2026-09-10T14:05:03
/// 2026-09-10T14:05:03Z
/// 2026-09-10 14:05:03
/// 2026-09-10T14:05:03.123
/// 2026-09-10T14:05:03.123Z
/// ```
///
/// Two deliberate choices:
///
/// * **A trailing `Z` is a literal, not a timezone.** The Kotlin patterns
///   quote it, so the wall-clock fields are taken as written.
///   [DateTime.parse] would instead read UTC and shift every receipt time by
///   the device offset — seven hours in WIB.
/// * **Parsing is a single regular expression, not five `DateFormat` probes.**
///   It removes the dependency on `intl` date-symbol initialisation (which
///   the host app would otherwise have to perform), and avoids four thrown
///   exceptions per row on a transaction list.
///
/// Month names are Indonesian and inline, matching the SDK's Indonesian copy.
/// Broader localisation is a separate, deliberate pass.
library;

class PosDates {
  PosDates._();

  static final RegExp _shape = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})' // date
    r'(?:[T ](\d{2}):(\d{2}):(\d{2})' // optional time, T or space separated
    r'(?:\.(\d{1,9}))?' // optional fractional seconds
    r'Z?)?$', // optional literal Z
  );

  static const List<String> _monthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Returns the parsed value, or `null` when [raw] is absent or unusable.
  ///
  /// Never throws: a malformed date on one transaction row must not break the
  /// list that contains it.
  static DateTime? parse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final match = _shape.firstMatch(trimmed);
    if (match == null) return null;

    final fraction = match.group(7);
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      _part(match.group(4)),
      _part(match.group(5)),
      _part(match.group(6)),
      fraction == null
          ? 0
          : int.parse(fraction.padRight(3, '0').substring(0, 3)),
    );
  }

  /// `10 Sep 2026`
  static String display(DateTime value) =>
      '${_two(value.day)} ${_monthsShort[value.month - 1]} ${value.year}';

  /// `14:05:03`
  static String time(DateTime value) =>
      '${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}';

  /// `2026-09-10` — the shape the `/pos/*` date-range parameters expect.
  static String apiDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)}';

  /// `2026-09-10T14:05:03` — the shape written into transaction payloads.
  static String apiDateTime(DateTime value) =>
      '${apiDate(value)}T${time(value)}';

  /// `10 Sep 2026 14:05:03`, or `-` when [raw] cannot be parsed.
  ///
  /// The convenience used by list rows, which receive the backend string
  /// directly and have nothing sensible to show on failure.
  static String displayRaw(String? raw) {
    final parsed = parse(raw);
    if (parsed == null) return '-';
    return '${display(parsed)} ${time(parsed)}';
  }

  static int _part(String? value) => value == null ? 0 : int.parse(value);

  static String _two(int value) => value.toString().padLeft(2, '0');
}
