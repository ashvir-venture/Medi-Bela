import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/prescription_photo.dart';

/// Opens the in-app camera for a prescription (owner 2026-11-18: the camera
/// opens directly, with "Choose from gallery" on the same screen, at most
/// [max] photos). Returns the photo paths, or null when the user closed it.
Future<List<String>?> openPrescriptionCamera(BuildContext context, {int max = 2}) {
  return Navigator.of(context, rootNavigator: true).push<List<String>>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => PrescriptionCameraScreen(max: max)),
  );
}

/// The demo's prescription camera: a live view with a paper frame, the
/// gallery on the left, a big shutter in the middle, the photos taken so far
/// with Retake, and "Use photos". When the camera can't start (no
/// permission, no camera), the gallery still works.
class PrescriptionCameraScreen extends ConsumerStatefulWidget {
  const PrescriptionCameraScreen({super.key, this.max = 2, this.camerasLoader});

  final int max;

  /// For tests: which cameras exist (the plugin is not available there).
  final Future<List<CameraDescription>> Function()? camerasLoader;

  @override
  ConsumerState<PrescriptionCameraScreen> createState() => _PrescriptionCameraScreenState();
}

class _PrescriptionCameraScreenState extends ConsumerState<PrescriptionCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _failed = false;
  bool _busy = false;
  final List<String> _photos = [];

  bool get _full => _photos.length >= widget.max;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera must be released while the app is away and opened again after.
    final c = _controller;
    if (state == AppLifecycleState.inactive && c != null && c.value.isInitialized) {
      _controller = null;
      c.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null && !_failed) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await (widget.camerasLoader ?? availableCameras)();
      final back = cameras.where((c) => c.lensDirection == CameraLensDirection.back).firstOrNull ?? cameras.firstOrNull;
      if (back == null) throw CameraException('none', 'No camera');
      // 1080p is sharp enough to read a prescription and stays a small upload.
      final c = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy || _full) return;
    setState(() => _busy = true);
    try {
      final file = await c.takePicture();
      setState(() => _photos.add(file.path));
    } catch (_) {
      // A missed shot: the user taps again.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gallery() async {
    final room = widget.max - _photos.length;
    if (room <= 0) return;
    final picker = ImagePicker();
    final List<XFile> files = room == 1
        ? [?(await picker.pickImage(source: ImageSource.gallery, maxWidth: prescriptionPhotoMaxSide, maxHeight: prescriptionPhotoMaxSide, imageQuality: prescriptionPhotoQuality))]
        : await picker.pickMultiImage(limit: room, maxWidth: prescriptionPhotoMaxSide, maxHeight: prescriptionPhotoMaxSide, imageQuality: prescriptionPhotoQuality);
    if (!mounted || files.isEmpty) return;
    setState(() => _photos.addAll(files.take(room).map((f) => f.path)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider).r18;
    final c = _controller;
    const ink = Color(0xFFFFFFFF);
    return Scaffold(
      // A camera screen is dark in both themes (the demo's view finder).
      backgroundColor: const Color(0xFF0F2137),
      body: SafeArea(
        child: Column(children: [
          Row(children: [
            IconButton(
              key: const ValueKey('camera-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              color: ink,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
            Expanded(
              child: Text(s.pagesN(_photos.length, widget.max),
                  textAlign: TextAlign.center, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 48),
          ]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(fit: StackFit.expand, children: [
                  if (c != null && c.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: c.value.previewSize?.height ?? 1080,
                        height: c.value.previewSize?.width ?? 1920,
                        child: CameraPreview(c),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF1C2B3A),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: _failed
                          ? Text(s.cameraUnavailable, key: const ValueKey('camera-failed'), textAlign: TextAlign.center, style: const TextStyle(color: ink))
                          : const CircularProgressIndicator(color: ink),
                    ),
                  const IgnorePointer(child: _FrameCorners()),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(999)),
                        child: Text(_full ? s.cameraFull : s.fitPaper,
                            style: const TextStyle(color: Color(0xFF143D6B), fontWeight: FontWeight.w700, fontSize: AppType.small)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(clipBehavior: Clip.none, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(_photos[i]), width: 56, height: 72, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 56, height: 72, color: const Color(0xFF1C2B3A))),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton.filled(
                            key: ValueKey('camera-remove-$i'),
                            tooltip: s.retake,
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            onPressed: () => setState(() => _photos.removeAt(i)),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _RoundButton(
                key: const ValueKey('camera-gallery'),
                icon: Icons.photo_library_outlined,
                label: s.fromGallery,
                onTap: _full ? null : _gallery,
              ),
              Semantics(
                button: true,
                label: s.takePhoto,
                child: GestureDetector(
                  key: const ValueKey('camera-shutter'),
                  onTap: (c != null && !_full && !_busy) ? _shoot : null,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ink, width: 4)),
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (c != null && !_full) ? ink : ink.withValues(alpha: 0.3),
                      ),
                      child: _busy ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(strokeWidth: 3)) : null,
                    ),
                  ),
                ),
              ),
              _RoundButton(
                key: const ValueKey('camera-done'),
                icon: Icons.check_rounded,
                label: s.usePhotos,
                filled: true,
                onTap: _photos.isEmpty ? null : () => Navigator.of(context).pop(List<String>.of(_photos)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(s.twoAtATime, style: TextStyle(color: ink.withValues(alpha: 0.75), fontSize: AppType.small)),
          ),
        ]),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFFFFFFF);
    final on = onTap != null;
    final bg = filled ? const Color(0xFF2F7A3A) : Colors.transparent;
    return Opacity(
      opacity: on ? 1 : 0.4,
      child: SizedBox(
        width: 84,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Material(
            color: bg,
            shape: CircleBorder(side: BorderSide(color: filled ? bg : ink, width: 1.5)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 56, height: 56, child: Icon(icon, color: ink)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: ink, fontSize: AppType.tiny, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// The four white corners of the paper frame.
class _FrameCorners extends StatelessWidget {
  const _FrameCorners();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CornersPainter());
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const inset = 24.0;
    const len = 36.0;
    final r = Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset - 40);
    for (final (corner, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner.translate(len * dx, 0), paint);
      canvas.drawLine(corner, corner.translate(0, len * dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
