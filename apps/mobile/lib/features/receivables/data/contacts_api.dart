
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

  /// Creates a shop the distributor sells to. Phone must be E.164
  /// (`+923001234567`); the API rejects anything else.
  Future<String> createContact({
    required String name,
    required String phone,
    String? email,
    bool whatsappOptIn = true,
  }) async {
    final trimmedEmail = email?.trim() ?? '';
    final response = await _apiClient.dio.post(
      '/contacts',
      data: {
        'name': name.trim(),
        'phone': phone.trim(),
        if (trimmedEmail.isNotEmpty) 'email': trimmedEmail,
        'whatsappOptIn': whatsappOptIn,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    throw const FormatException(
      'The server returned an invalid customer response.',
    );
  }
}
