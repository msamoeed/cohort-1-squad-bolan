import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/image_picker_service.dart';
import '../data/invoice_api.dart';
import '../domain/invoice_extraction.dart';

final imagePickerServiceProvider = Provider<ImagePickerService>((ref) {
  return ImagePickerService();
});

final invoiceApiProvider = Provider<InvoiceApi>((ref) {
  return InvoiceApi(ref.watch(apiClientProvider));
});

final invoiceExtractionProvider = FutureProvider.family<InvoiceExtraction, String>((ref, extractionId) async {
  final api = ref.watch(invoiceApiProvider);
  return api.getExtraction(extractionId);
});
