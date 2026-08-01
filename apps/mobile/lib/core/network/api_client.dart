import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../config/app_config.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(firebaseAuthProvider)),
);

class ApiClient {
  ApiClient(FirebaseAuth auth)
    : dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)) {
    dio.interceptors.add(_FirebaseAuthInterceptor(auth));
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          logPrint: (message) => debugPrint('[Dio] $message'),
        ),
      );
    }
  }

  final Dio dio;
}

class _FirebaseAuthInterceptor extends Interceptor {
  _FirebaseAuthInterceptor(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = _auth.currentUser;
    final token = await user?.getIdToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}
