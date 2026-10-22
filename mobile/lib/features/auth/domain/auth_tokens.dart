class AuthTokens {
  const AuthTokens({required this.accessToken});

  final String accessToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(accessToken: json['accessToken'] as String);
  }
}
