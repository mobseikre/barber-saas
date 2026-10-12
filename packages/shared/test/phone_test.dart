import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('normalizeLibyanPhone', () {
    test('accepts the common ways Libyans write a mobile number', () {
      for (final input in [
        '0912345678',
        '912345678',
        '+218912345678',
        '00218912345678',
        '218912345678',
        '91 234 5678',
        '091-234-5678',
        '٠٩١٢٣٤٥٦٧٨',
      ]) {
        expect(normalizeLibyanPhone(input), '218912345678', reason: input);
      }
    });

    test('rejects numbers that are not a 9-digit mobile starting with 9', () {
      for (final input in ['', '12345', '0812345678', '09123456789', 'abc', '+2189123']) {
        expect(normalizeLibyanPhone(input), isNull, reason: input);
      }
    });
  });

  test('phoneToAuthEmail builds the internal email', () {
    expect(phoneToAuthEmail('218912345678'), '218912345678@app.local');
  });

  test('formatLibyanPhone groups digits like the design', () {
    expect(formatLibyanPhone('218912345678'), '+218 91 234 5678');
  });

  test('parseTstzRange reads Postgres range literals', () {
    final range = parseTstzRange('["2026-10-10 09:00:00+00","2026-10-10 09:30:00+00")');
    expect(range.end.difference(range.start), const Duration(minutes: 30));
    expect(range.start.toUtc(), DateTime.utc(2026, 10, 10, 9));
  });
}
