import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  test('a stored path becomes a public URL on the given Supabase address', () {
    expect(
      publicStorageUrl('avatars/u1/avatar.jpg?v=1', base: 'http://10.0.2.2:54321'),
      'http://10.0.2.2:54321/storage/v1/object/public/avatars/u1/avatar.jpg?v=1',
    );
    expect(
      publicStorageUrl('avatars/u1/avatar.jpg?v=1', base: 'http://127.0.0.1:54321'),
      'http://127.0.0.1:54321/storage/v1/object/public/avatars/u1/avatar.jpg?v=1',
      reason: 'the same stored value works from every device',
    );
  });

  test('full URLs and empty values are passed through', () {
    expect(publicStorageUrl('https://cdn.example.com/a.png', base: 'http://x'), 'https://cdn.example.com/a.png');
    expect(publicStorageUrl(null, base: 'http://x'), isNull);
    expect(publicStorageUrl('', base: 'http://x'), isNull);
  });
}
