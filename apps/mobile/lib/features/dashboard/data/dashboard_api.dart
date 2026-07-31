import '../../../core/network/api_client.dart';
import '../domain/dashboard_metrics.dart';

class DashboardApi {
  DashboardApi(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardMetrics> getDashboardMetrics() async {
    final response = await _apiClient.dio.get('/dashboard');
    return DashboardMetrics.fromJson(response.data as Map<String, dynamic>);
  }
}
