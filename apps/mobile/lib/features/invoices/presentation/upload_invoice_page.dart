import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'invoice_providers.dart';

class UploadInvoicePage extends ConsumerStatefulWidget {
  const UploadInvoicePage({super.key});

  @override
  ConsumerState<UploadInvoicePage> createState() => _UploadInvoicePageState();
}

class _UploadInvoicePageState extends ConsumerState<UploadInvoicePage> {
  _UploadStage? _stage;
  _InvoiceSource? _activeSource;

  bool get _isBusy => _stage != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add invoice')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Turn an invoice into a receivable',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a clear photo or choose one from your gallery.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.document_scanner_rounded,
                        size: 38,
                        color: AppColors.brand,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Upload invoice',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Camera or gallery',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isBusy
                  ? null
                  : () => _selectAndUpload(_InvoiceSource.camera),
              icon: _buttonIcon(
                source: _InvoiceSource.camera,
                idleIcon: Icons.camera_alt_rounded,
              ),
              label: Text(_buttonLabel(_InvoiceSource.camera, 'Take a photo')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isBusy
                  ? null
                  : () => _selectAndUpload(_InvoiceSource.gallery),
              icon: _buttonIcon(
                source: _InvoiceSource.gallery,
                idleIcon: Icons.photo_library_outlined,
              ),
              label: Text(
                _buttonLabel(_InvoiceSource.gallery, 'Choose from gallery'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAndUpload(_InvoiceSource source) async {
    try {
      final picker = ref.read(imagePickerServiceProvider);
      final image = source == _InvoiceSource.camera
          ? await picker.pickFromCamera()
          : await picker.pickFromGallery();

      if (image == null || !mounted) return;
      await _uploadImage(image, source);
    } on PlatformException catch (error) {
      _showError(
        error.message ?? 'Unable to access the selected image source.',
      );
    } catch (_) {
      _showError('Unable to access the selected image source.');
    }
  }

  Future<void> _recoverLostImage() async {
    try {
      final image = await ref
          .read(imagePickerServiceProvider)
          .retrieveLostImage();
      if (image == null || !mounted || _isBusy) return;
      await _uploadImage(image, _InvoiceSource.camera);
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Unable to recover the selected image.');
    } catch (_) {
      _showError('Unable to recover the selected image.');
    }
  }

  Future<void> _uploadImage(File image, _InvoiceSource source) async {
    try {
      setState(() {
        _activeSource = source;
        _stage = _UploadStage.uploading;
      });

      final bytes = await image.readAsBytes();
      final imageType = _detectImageType(bytes);
      final uploadId = await ref
          .read(invoiceApiProvider)
          .uploadInvoice(
            base64: base64Encode(bytes),
            filename:
                'invoice-${DateTime.now().millisecondsSinceEpoch}.${imageType.extension}',
            contentType: imageType.contentType,
          );

      if (!mounted) return;
      setState(() => _stage = _UploadStage.extracting);

      final extractionId = await ref
          .read(invoiceApiProvider)
          .createExtraction(uploadId: uploadId);

      if (!mounted) return;
      context.push(
        '/review/${Uri.encodeComponent(extractionId)}',
        extra: image.path,
      );
    } on DioException catch (error) {
      _showError(_dioMessage(error));
    } on FormatException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(
        _stage == _UploadStage.extracting
            ? 'Invoice extraction failed. Please try again.'
            : 'Invoice upload failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _stage = null;
          _activeSource = null;
        });
      }
    }
  }

  Widget _buttonIcon({
    required _InvoiceSource source,
    required IconData idleIcon,
  }) {
    if (_isBusy && _activeSource == source) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(idleIcon);
  }

  String _buttonLabel(_InvoiceSource source, String idleLabel) {
    if (!_isBusy || _activeSource != source) return idleLabel;
    return _stage == _UploadStage.uploading
        ? 'Uploading invoice…'
        : 'Reading invoice…';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  String _dioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List) return message.join('\n');
    }
    final isNetworkFailure =
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout;
    return isNetworkFailure
        ? 'Unable to reach the server. Check your connection and try again.'
        : _stage == _UploadStage.extracting
        ? 'Invoice extraction failed. Please try again.'
        : 'Invoice upload failed. Please try again.';
  }

  _ImageType _detectImageType(List<int> bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return const _ImageType(contentType: 'image/png', extension: 'png');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return const _ImageType(contentType: 'image/jpeg', extension: 'jpg');
    }
    throw const FormatException(
      'Only JPEG and PNG invoice images are supported.',
    );
  }
}

enum _InvoiceSource { camera, gallery }

enum _UploadStage { uploading, extracting }

class _ImageType {
  const _ImageType({required this.contentType, required this.extension});

  final String contentType;
  final String extension;
}
