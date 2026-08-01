import '../../../core/network/api_client.dart';
import '../domain/user_profile.dart';

class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;

  Future<UserProfile> getProfile() async {
    final response = await _client.dio.get('/users/me');
    return _parse(response.data);
  }

  Future<UserProfile> upsertProfile({
    required String name,
    required String phone,
  }) async {
    final response = await _client.dio.put(
      '/users/me',
      data: {'name': name.trim(), 'phone': phone.trim()},
    );
    return _parse(response.data);
  }

  UserProfile _parse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'The server returned an invalid user profile response.',
      );
    }
    return UserProfile.fromJson(data);
  }
}
