import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/dashboard_api.dart';
import '../domain/dashboard_metrics.dart';

final dashboardApiProvider = Provider<DashboardApi>((ref) => DashboardApi(ref.watch(apiClientProvider)));
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final api = ref.watch(dashboardApiProvider);
  return api.getDashboardMetrics();
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return metricsAsync.when(
      data: (metrics) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
          children: [
            Row(children: [
              const CircleAvatar(backgroundColor: AppColors.mint, child: Icon(Icons.storefront_rounded, color: AppColors.brand)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Assalam-o-alaikum, Ahmed', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const Text('Here is today’s collection picture', style: TextStyle(color: AppColors.muted))])),
              IconButton(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Sign out',
              ),
            ]),
            const SizedBox(height: 26),
            Text('Outstanding balance', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 6),
            AmountText(metrics.outstandingTotal, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 18),
            Row(children: [
              _Metric(label: 'Overdue', value: '${metrics.overdueTotal.toInt()}', color: AppColors.danger),
              const SizedBox(width: 12),
              _Metric(label: 'Due this week', value: '${metrics.customerCount}', color: AppColors.warning),
            ]),
            const SizedBox(height: 28),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Needs attention', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), TextButton(onPressed: () => context.go('/receivables'), child: const Text('See all'))]),
            if (metrics.overdueTotal <= 0) const Padding(padding: EdgeInsets.all(24), child: Text('No overdue payments. Great work!')),
          ],
        ),
      ),
      loading: () => const SafeArea(child: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => SafeArea(child: Center(child: Text('Unable to load dashboard data.'))),
    );
  }
}

class _Metric extends StatelessWidget { const _Metric({required this.label, required this.value, required this.color}); final String label; final String value; final Color color; @override Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: color)), Text(label, style: const TextStyle(color: AppColors.muted))]))); }
