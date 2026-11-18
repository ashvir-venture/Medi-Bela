import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/direct_uploader.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../prescription/domain/prescription_photo.dart';

/// Round 18 (client point 1d): photo of the strip / pack. Camera or gallery;
/// the upload happens after Save (PackPhotoUploader).
class PackPhotoField extends ConsumerWidget {
  const PackPhotoField({super.key, required this.picked, required this.existing, required this.onPicked});

  final String? picked;
  final bool existing;
  final ValueChanged<String?> onPicked;

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: prescriptionPhotoMaxSide,
      maxHeight: prescriptionPhotoMaxSide,
      imageQuality: prescriptionPhotoQuality,
    );
    if (file != null) onPicked(file.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider).r18;
    final p = context.palette;
    final has = picked != null || existing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(has ? Icons.check_circle_outline_rounded : Icons.photo_camera_outlined, color: p.head),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(has ? s.packPhotoAdded : s.packPhoto, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(s.packPhotoSub, style: TextStyle(color: p.muted, fontSize: AppType.small)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(ref.watch(stringsProvider).r15.takePhoto),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.image_outlined),
                label: Text(ref.watch(stringsProvider).r15.fromGallery),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Direct upload (DirectUploader) → attach to the medicine. Best effort, after Save.
class PackPhotoUploader {
  PackPhotoUploader(this._dio, this._uploader);

  final Dio _dio;
  final DirectUploader _uploader;

  Future<void> upload(String routineId, String path, {String? forUserId}) async {
    final publicId = await _uploader.upload(path, purpose: 'pack', forUserId: forUserId);
    await _dio.put<dynamic>(
      '${ApiEndpoints.medicineRoutine(routineId)}/pack-photo',
      data: {'publicId': publicId},
      queryParameters: {'forUserId': ?forUserId},
    );
  }
}

final packPhotoUploaderProvider =
    Provider<PackPhotoUploader>((ref) => PackPhotoUploader(ref.watch(dioClientProvider).dio, ref.watch(directUploaderProvider)));
