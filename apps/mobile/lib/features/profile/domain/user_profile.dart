class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.phone,
    this.email,
  });

  final String uid;
  final String fullName;
  final String phone;
  final String? email;

  String get displayFirstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final phone = json['phone'];
    final uid = json['uid'];

    if (uid is! String || uid.trim().isEmpty) {
      throw const FormatException(
        'The user profile response did not include a uid.',
      );
    }
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException(
        'The user profile response did not include a name.',
      );
    }
    if (phone is! String || phone.trim().isEmpty) {
      throw const FormatException(
        'The user profile response did not include a phone number.',
      );
    }

    final email = json['email'];
    return UserProfile(
      uid: uid,
      fullName: name.trim(),
      phone: phone.trim(),
      email: email is String && email.trim().isNotEmpty ? email.trim() : null,
    );
  }
}
