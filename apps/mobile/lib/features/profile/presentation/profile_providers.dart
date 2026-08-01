import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/profile_api.dart';
import '../domain/user_profile.dart';

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.watch(apiClientProvider));
});

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth.currentUser == null) {
    throw Exception('Please sign in to load your profile.');
  }
  return ref.watch(profileApiProvider).getProfile();
});
