import '../../../core/network/api_client.dart';
import '../domain/reminder_draft.dart';

class RemindersApi {
  RemindersApi(this._client);

  final ApiClient _client;

  Future<ReminderDraft> createDraft(String contactId) async {
    final response = await _client.dio.post(
      '/contacts/${Uri.encodeComponent(contactId)}/reminders/draft',
      data: const <String, dynamic>{},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'The server returned an invalid reminder draft response.',
      );
    }
    return ReminderDraft.fromJson(data);
  }
}
