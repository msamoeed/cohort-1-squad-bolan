
import '../../../core/network/api_client.dart';
import '../domain/contact.dart';

class ContactsApi {
  ContactsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Contact>> listContacts() async {
    final response = await _apiClient.dio.get('/contacts');
    final data = response.data;

    if (data is! List) {
      return const <Contact>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(Contact.fromJson)
        .toList(growable: false);
  }
}
