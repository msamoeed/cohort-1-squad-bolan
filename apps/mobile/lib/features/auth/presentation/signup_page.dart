import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/presentation/profile_providers.dart';
import 'auth_providers.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  bool _passwordVisible = false;
  bool _accountCreated = false;

  static final _e164 = RegExp(r'^\+[1-9]\d{7,14}$');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Create your HisaabAI account',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start tracking your receivables.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              decoration: _inputDecoration(
                                colorScheme,
                                label: 'Full name',
                                hint: 'Ahmed Khan',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              validator: _validateName,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              decoration: _inputDecoration(
                                colorScheme,
                                label: 'Phone number',
                                hint: '+923001234567',
                                prefixIcon: Icons.phone_outlined,
                              ),
                              validator: _validatePhone,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              enabled: !_accountCreated,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newUsername],
                              decoration: _inputDecoration(
                                colorScheme,
                                label: 'Email address',
                                hint: 'you@company.com',
                                prefixIcon: Icons.alternate_email_rounded,
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !_accountCreated,
                              obscureText: !_passwordVisible,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: _inputDecoration(
                                colorScheme,
                                label: 'Password',
                                hint: 'At least 6 characters',
                                prefixIcon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _passwordVisible = !_passwordVisible,
                                  ),
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                  ),
                                ),
                              ),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              enabled: !_accountCreated,
                              obscureText: !_passwordVisible,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: _inputDecoration(
                                colorScheme,
                                label: 'Confirm password',
                                hint: 'Enter your password again',
                                prefixIcon: Icons.lock_reset_rounded,
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) {
                                if (!_submitting) _signUp();
                              },
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _submitting ? null : _signUp,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(
                                _submitting
                                    ? (_accountCreated
                                          ? 'Saving profile…'
                                          : 'Creating account…')
                                    : (_accountCreated
                                          ? 'Save profile'
                                          : 'Create account'),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => context.go('/login'),
                              child: const Text(
                                'Already have an account? Sign in',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    ColorScheme colorScheme, {
    required String label,
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    return name.isEmpty ? 'Enter your full name.' : null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    return _e164.hasMatch(phone)
        ? null
        : 'Enter phone in E.164 format, e.g. +923001234567.';
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailPattern.hasMatch(email) ? null : 'Enter a valid email address.';
  }

  String? _validatePassword(String? value) {
    return value != null && value.length >= 6
        ? null
        : 'Password must be at least 6 characters.';
  }

  Future<void> _signUp() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      if (!_accountCreated) {
        await ref
            .read(authRepositoryProvider)
            .signUpWithEmail(
              _emailController.text.trim(),
              _passwordController.text,
            );
        if (!mounted) return;
        setState(() => _accountCreated = true);
      }

      await _saveProfile();
      if (!mounted) return;
      ref.invalidate(userProfileProvider);
      context.go('/home');
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_firebaseErrorMessage(error));
    } on DioException catch (error) {
      if (mounted) await _handleProfileFailure(_profileErrorMessage(error));
    } catch (_) {
      if (mounted) {
        if (_accountCreated) {
          await _handleProfileFailure(
            'Unable to save your profile. Please try again.',
          );
        } else {
          _showError('Unable to create your account. Please try again.');
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveProfile() async {
    await ref
        .read(profileApiProvider)
        .upsertProfile(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
  }

  Future<void> _handleProfileFailure(String message) async {
    final action = await showDialog<_ProfileFailureAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profile not saved'),
        content: Text(
          '$message Your account was created, but we still need to save your name and phone number.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ProfileFailureAction.signOut),
            child: const Text('Sign out'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ProfileFailureAction.retry),
            child: const Text('Retry'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (action == _ProfileFailureAction.retry) {
      setState(() => _submitting = true);
      try {
        await _saveProfile();
        if (!mounted) return;
        ref.invalidate(userProfileProvider);
        context.go('/home');
      } catch (error) {
        if (!mounted) return;
        final retryMessage = error is DioException
            ? _profileErrorMessage(error)
            : 'Unable to save your profile. Please try again.';
        await _handleProfileFailure(retryMessage);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    if (action == _ProfileFailureAction.signOut) {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      setState(() => _accountCreated = false);
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'An account already exists for this email.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Choose a stronger password.',
      'operation-not-allowed' =>
        'Email signup is not enabled. Contact support.',
      'network-request-failed' =>
        'Unable to connect. Check your internet connection.',
      _ => error.message ?? 'Unable to create your account.',
    };
  }

  String _profileErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      if (message is List && message.isNotEmpty) {
        return message.map((item) => item.toString()).join('\n');
      }
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Unable to reach the server. Check your connection and try again.';
    }
    return 'Unable to save your profile. Please try again.';
  }

  void _showError(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: colorScheme.errorContainer,
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

enum _ProfileFailureAction { retry, signOut }
