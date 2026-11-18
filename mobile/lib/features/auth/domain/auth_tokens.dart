class AuthTokens {
  const AuthTokens({required this.accessToken, this.refreshToken});

  /// 15 minutes (Round 18); renewed with [refreshToken].
  final String accessToken;

  /// Round 18: 60 days, rotated on every refresh. Kept only in secure storage.
  final String? refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
    );
  }
}
