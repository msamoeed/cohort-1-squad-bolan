class ReminderDraft {
  const ReminderDraft({required this.message, required this.whatsappUri});

  final String message;
  final Uri whatsappUri;

  factory ReminderDraft.fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    final whatsappUrl = json['whatsappUrl'];
    final whatsappUri = whatsappUrl is String
        ? Uri.tryParse(whatsappUrl)
        : null;

    if (message is! String || message.trim().isEmpty) {
      throw const FormatException(
        'The reminder draft response did not include a message.',
      );
    }
    if (whatsappUri == null ||
        whatsappUri.scheme != 'https' ||
        whatsappUri.host != 'wa.me' ||
        whatsappUri.pathSegments.isEmpty ||
        whatsappUri.pathSegments.first.isEmpty) {
      throw const FormatException(
        'The reminder draft response included an invalid WhatsApp link.',
      );
    }

    return ReminderDraft(message: message, whatsappUri: whatsappUri);
  }
}
