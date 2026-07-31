import '../../../core/network/api_client.dart';
import '../domain/invoice_extraction.dart';

class InvoiceApi {
  InvoiceApi(this._client);

  final ApiClient _client;

  Future<String> uploadInvoice({
    required String base64,
    String filename = 'invoice.jpg',
    String contentType = 'image/jpeg',
  }) async {
    final response = await _client.dio.post(
      '/uploads',
      data: {
        'base64': base64,
        'filename': filename,
        'contentType': contentType,
      },
    );
    return _readId(response.data, 'upload');
  }

  Future<String> createExtraction({required String uploadId}) async {
    final response = await _client.dio.post(
      '/invoice-extractions',
      data: {'uploadId': uploadId},
    );
    return _readId(response.data, 'invoice extraction');
  }

  Future<InvoiceExtraction> getExtraction(String extractionId) async {
    final response = await _client.dio.get('/invoice-extractions/$extractionId');
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('The server returned an invalid invoice extraction response.');
    }
    return InvoiceExtraction.fromJson(data);
  }

  Future<String> approveInvoice({
    required String extractionId,
    required String contactId,
    String? invoiceNumber,
    required String invoiceDate,
    String? dueDate,
    required double total,
    required List<InvoiceApprovalItem> items,
  }) async {
    final response = await _client.dio.post(
      '/invoices/approve',
      data: {
        'extractionId': extractionId,
        'contactId': contactId,
        if (invoiceNumber != null && invoiceNumber.isNotEmpty) 'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate,
        if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
        'total': total,
        'items': items.map((item) => item.toJson()).toList(),
      },
    );
    return _readId(response.data, 'invoice approval');
  }

  String _readId(dynamic data, String resource) {
    if (data is Map<String, dynamic>) {
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    throw FormatException('The server returned an invalid $resource response.');
  }
}
