import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/contacts_api.dart';
import '../domain/contact.dart';
import '../domain/ledger_entry.dart';
import '../domain/receivable.dart';

final contactsApiProvider = Provider<ContactsApi>((ref) => ContactsApi(ref.watch(apiClientProvider)));
final receivablesProvider = AsyncNotifierProvider<ReceivablesController, List<Customer>>(ReceivablesController.new);

final ledgerProvider = FutureProvider.family<List<LedgerEntry>, String>((ref, contactId) async {
  final response = await ref.watch(apiClientProvider).dio.get('/contacts/$contactId/ledger');
  final data = response.data;
  if (data is! List) return const <LedgerEntry>[];
  return data
      .whereType<Map<String, dynamic>>()
      .map(LedgerEntry.fromJson)
      .toList(growable: false);
});

class ReceivablesController extends AsyncNotifier<List<Customer>> {
  @override
  FutureOr<List<Customer>> build() async {
    final auth = ref.watch(firebaseAuthProvider);
    if (auth.currentUser == null) {
      throw Exception('Please sign in to load contacts.');
    }

    final contacts = await ref.watch(contactsApiProvider).listContacts();
    return contacts.map(_toCustomer).toList(growable: false);
  }
}

Customer _toCustomer(Contact contact) {
  return Customer(
    id: contact.id,
    name: contact.name,
    phone: contact.phone,
    balance: contact.currentBalance,
    dueDate: contact.earliestDueDate,
    invoiceCount: contact.invoiceCount,
    isOverdue: contact.overdue,
  );
}
