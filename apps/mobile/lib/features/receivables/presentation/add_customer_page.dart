import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'receivables_controller.dart';

/// Creates a shop the distributor sells to on credit. Every other flow —
/// approving an invoice, recording a payment, drafting a reminder — needs a
/// contact to exist first, and `POST /contacts` had no caller in the app.
class AddCustomerPage extends ConsumerStatefulWidget {
  const AddCustomerPage({super.key});

  @override
  ConsumerState<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends ConsumerState<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+92');
  final _emailController = TextEditingController();

  bool _whatsappOptIn = true;
  bool _isSaving = false;
  String? _submitError;

  // Mirrors the API's CreateContactDto rule so a bad number is caught before
  // the round trip.
  static final _e164 = RegExp(r'^\+[1-9]\d{7,14}$');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add customer')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'New shop',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add the shop once, then every invoice and reminder can be '
                'linked to it.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 26),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Shop name',
                  hintText: 'Bolan Kiryana Store',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter the shop name.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp number',
                  hintText: '+923001234567',
                ),
                validator: (value) {
                  final phone = (value ?? '').trim();
                  if (phone.isEmpty) return 'Enter the shop\'s phone number.';
                  if (!_e164.hasMatch(phone)) {
                    return 'Use the international format, e.g. +923001234567.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return null;
                  return email.contains('@') && email.contains('.')
                      ? null
                      : 'Enter a valid email or leave this empty.';
                },
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _whatsappOptIn,
                onChanged: (value) => setState(() => _whatsappOptIn = value),
                title: const Text('Send collection reminders on WhatsApp'),
              ),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDEAE8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _submitError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _submitError = null);
      return;
    }

    setState(() {
      _isSaving = true;
      _submitError = null;
    });

    try {
      await ref
          .read(contactsApiProvider)
          .createContact(
            name: _nameController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            whatsappOptIn: _whatsappOptIn,
          );

      ref.invalidate(receivablesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${_nameController.text.trim()} added.'),
        ),
      );
      context.pop();
    } on DioException catch (error) {
      _showError(_messageFor(error));
    } catch (_) {
      _showError('Unable to save this customer. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _submitError = message);
  }

  String _messageFor(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;

    if (status != null && status >= 500) {
      return 'The server could not save this customer (error $status). Please try again.';
    }
    if (data is Map<String, dynamic> && data['message'] != null) {
      final raw = data['message'];
      return raw is List ? raw.join('\n') : raw.toString();
    }
    const networkFailures = {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    };
    return networkFailures.contains(error.type)
        ? 'Unable to reach the server. Check your connection and try again.'
        : 'Unable to save this customer. Please try again.';
  }
}
