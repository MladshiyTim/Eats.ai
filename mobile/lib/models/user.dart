/// Represents the authenticated user returned by /auth/me/ and login/register.
class User {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
      };

  /// Returns display name: full name if available, else username.
  String get displayName {
    final parts = [firstName, lastName].where((p) => p != null && p.isNotEmpty).join(' ');
    return parts.isNotEmpty ? parts : username;
  }
}
