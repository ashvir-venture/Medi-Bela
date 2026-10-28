/// Mirrors the backend's `SafeUser` shape (`sanitizeUser()` output) —
/// never contains a password hash or refresh token.
class UserModel {
  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.address,
    required this.role,
    required this.accountStatus,
    required this.languageCode,
    required this.notificationsEnabled,
    required this.profileVisibleToFamily,
    this.medicineRemindersEnabled = true,
    this.noticesEnabled = true,
  });

  final String id;
  final String phone;
  final String name;
  final String? address;
  final String role; // USER | ADMIN | PHARMACIST
  final String accountStatus;
  final String languageCode; // EN | BN
  final bool notificationsEnabled;
  final bool profileVisibleToFamily;
  /// Off: no reminders on this phone, no backstop push, no family missed-dose alerts.
  final bool medicineRemindersEnabled;
  /// Off: notices are not pushed (still listed in the app).
  final bool noticesEnabled;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      role: json['role'] as String? ?? 'USER',
      accountStatus: json['accountStatus'] as String? ?? 'ACTIVE',
      languageCode: json['languagePreference'] as String? ?? 'EN',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      profileVisibleToFamily:
          json['profileVisibleToFamily'] as bool? ?? true,
      medicineRemindersEnabled: json['medicineRemindersEnabled'] as bool? ?? true,
      noticesEnabled: json['noticesEnabled'] as bool? ?? true,
    );
  }
}
