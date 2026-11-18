import 'package:dio/dio.dart';

/// Round 18 (owner 2026-11-17): a photo goes from the phone straight to
/// Cloudinary. The API signs one private upload at a public id it chose
/// (POST /uploads/sign); the phone sends the file to Cloudinary with those
/// fields; the endpoint that uses the photo checks it and stores it. The
/// Cloudinary secret never reaches the phone.
class DirectUploader {
  DirectUploader(this._api, {Dio? cloud}) : _cloud = cloud ?? Dio();

  /// The app's Dio (auth headers, refresh).
  final Dio _api;

  /// A plain Dio for Cloudinary: no app headers go there.
  final Dio _cloud;

  /// Uploads [path] for [purpose] (prescription | record | pack); returns its public id.
  Future<String> upload(String path, {required String purpose, String? forUserId}) async {
    final sign = (await _api.post<Map<String, dynamic>>(
      '/uploads/sign',
      data: {'purpose': purpose},
      queryParameters: {'forUserId': ?forUserId},
    ))
        .data!;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path),
      'api_key': sign['apiKey'],
      'timestamp': sign['timestamp'],
      'signature': sign['signature'],
      'public_id': sign['publicId'],
      'type': sign['type'],
      'allowed_formats': sign['allowedFormats'],
    });
    await _cloud.post<dynamic>(sign['uploadUrl'] as String, data: form);
    return sign['publicId'] as String;
  }
}
