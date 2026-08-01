import 'package:flutter_test/flutter_test.dart';
import 'package:hisaabai_mobile/features/reminders/domain/reminder_draft.dart';

void main() {
  group('ReminderDraft.fromJson', () {
    test('parses a valid backend reminder draft', () {
      final draft = ReminderDraft.fromJson({
        'id': 'reminder-1',
        'message': 'Your payment is due.',
        'whatsappUrl':
            'https://wa.me/923001234567?text=Your%20payment%20is%20due.',
      });

      expect(draft.message, 'Your payment is due.');
      expect(draft.whatsappUri.host, 'wa.me');
      expect(draft.whatsappUri.pathSegments.single, '923001234567');
    });

    test('rejects a response without a message', () {
      expect(
        () => ReminderDraft.fromJson({
          'whatsappUrl': 'https://wa.me/923001234567',
        }),
        throwsFormatException,
      );
    });

    test('rejects a non-WhatsApp URL', () {
      expect(
        () => ReminderDraft.fromJson({
          'message': 'Your payment is due.',
          'whatsappUrl': 'https://example.com/message',
        }),
        throwsFormatException,
      );
    });
  });
}
