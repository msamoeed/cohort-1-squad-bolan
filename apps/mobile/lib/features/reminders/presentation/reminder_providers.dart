import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/reminders_api.dart';

final remindersApiProvider = Provider<RemindersApi>((ref) {
  return RemindersApi(ref.watch(apiClientProvider));
});
