/// Sign-up and family invitations take any 11-digit number, sent as typed
/// (spaces and dashes dropped, no +880 added), like the staff accounts.
String cleanPhone(String raw) => raw.trim().replaceAll(RegExp(r'[\s\-().]'), '');

bool isValidPhone(String raw) => RegExp(r'^\d{11}$').hasMatch(cleanPhone(raw));
