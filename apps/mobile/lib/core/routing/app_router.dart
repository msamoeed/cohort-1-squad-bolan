import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/invoices/presentation/invoice_review_page.dart';
import '../../features/invoices/presentation/upload_invoice_page.dart';
import '../../features/receivables/presentation/customer_detail_page.dart';
import '../../features/receivables/presentation/record_payment_page.dart';
import '../../features/receivables/presentation/receivables_page.dart';
import '../../shared/widgets/app_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/login';
      final isLoggedIn = authState.when(
        data: (user) => user != null,
        loading: () => false,
        error: (error, stackTrace) => false,
      );

      if (authState.isLoading) return null;
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/receivables',
            builder: (context, state) => const ReceivablesPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/upload',
        builder: (context, state) => const UploadInvoicePage(),
      ),
      GoRoute(
        path: '/review/:extractionId',
        builder: (context, state) => InvoiceReviewPage(
          extractionId: state.pathParameters['extractionId']!,
          imagePath: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: '/customer/:id',
        builder: (context, state) =>
            CustomerDetailPage(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/payment/:id',
        builder: (context, state) =>
            RecordPaymentPage(customerId: state.pathParameters['id']!),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page unavailable: ${state.error}'))),
  );
});
