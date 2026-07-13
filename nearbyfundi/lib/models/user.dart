class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? locale;
  final String token;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.locale,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json, String token) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      locale: json['locale'] ?? 'en',
      token: token,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'locale': locale,
  };
}