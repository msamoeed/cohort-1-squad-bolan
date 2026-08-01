import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabai_mobile/features/profile/domain/user_profile.dart';

void main() {
  group('UserProfile.fromJson', () {
    test('parses a valid profile payload', () {
      final profile = UserProfile.fromJson({
        'uid': 'uid-1',
        'name': 'Ahmed Khan',
        'phone': '+923001234567',
        'email': 'ahmed@example.com',
      });

      expect(profile.uid, 'uid-1');
      expect(profile.fullName, 'Ahmed Khan');
      expect(profile.phone, '+923001234567');
      expect(profile.email, 'ahmed@example.com');
      expect(profile.displayFirstName, 'Ahmed');
    });

    test('rejects a response without a name', () {
      expect(
        () => UserProfile.fromJson({'uid': 'uid-1', 'phone': '+923001234567'}),
        throwsFormatException,
      );
    });

    test('handles single-word names for displayFirstName', () {
      final profile = UserProfile.fromJson({
        'uid': 'uid-1',
        'name': '  Noor  ',
        'phone': '+923001234567',
      });
      expect(profile.displayFirstName, 'Noor');
    });
  });
}
