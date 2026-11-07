import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart' show PlatformException, DeviceOrientation;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:get_video_thumbnail/get_video_thumbnail.dart' as thumb;
import 'package:get_video_thumbnail/index.dart' as thumb_format;

import '../core/blink_home_api.dart';
import '../core/blink_original_music.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// Full camera + gallery + authenticated upload to the existing Blink API.
class BlinkRealCaptureScreen extends StatefulWidget {
  const BlinkRealCaptureScreen({
    super.key,
    this.initialVideo = false,
    this.preferReel = false,
  });
  final bool initialVideo;
  final bool preferReel;

  @override
  State<BlinkRealCaptureScreen> createState() => _BlinkRealCaptureScreenState();
}

class _BlinkRealCaptureScreenState extends State<BlinkRealCaptureScreen> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _caption = TextEditingController();
  final BlinkOriginalPlayer _soundtrackPlayer = BlinkOriginalPlayer();
  bool _soundtrackPlaying = false;
  List<CameraDescription> _cameras = [];
  CameraController? _camera;
  VideoPlayerController? _preview;
  XFile? _picked;
  late bool _videoMode;
  bool _recording = false;
  bool _uploading = false;
  bool _flash = false;
  // Web-parity AR lenses. Detection stays on this device.
  static const _lenses = <(String, String, String)>[
    ('none', '◯', 'Natural'),
    ('cat', '🐱', 'Kitty AR'),
    ('dog', '🐶', 'Puppy AR'),
    ('butterfly', '🦋', 'Fairy'),
    ('heart', '💖', 'Love Glow'),
    ('crown', '👑', 'Royal Gold'),
    ('glasses', '😎', 'Neon Shades'),
    ('cyber', '⚡', 'Cyber'),
    ('blush', '🌸', 'Soft Glam'),
    ('party', '🎉', 'Festival'),
  ];
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  final GlobalKey _mediaBoundary = GlobalKey();
  String _lens = 'none';
  Rect? _faceBounds; // Normalized in portrait display coordinates.
  bool _processingFace = false;
  DateTime _lastFaceFrame = DateTime.fromMillisecondsSinceEpoch(0);
  String? _musicTrackId;
  static const _soundtracks = <String, String>{
    'sunny-pop': '☀️ Sunny Pop',
    'dream-cloud': '☁️ Dream Cloud',
    'neon-night': '🌃 Neon Night',
    'golden-hour': '🌅 Golden Hour',
    'little-steps': '✨ Little Steps',
    'soft-waves': '🌊 Soft Waves',
  };
  late bool _publishReel;
  int _cameraIndex = 0;
  String? _cameraError;
  String? _error;

  // Camera operations run sequentially. The older implementation could dispose
  // a controller while its initialize() was still awaiting Android CameraX.
  Future<void> _cameraQueue = Future<void>.value();
  int _cameraGeneration = 0;
  bool _appActive = true;
  bool _closed = false;
  bool _pickerActive = false;
  final List<Directory> _temporaryMediaDirectories = [];

  @override
  void initState() {
    super.initState();
    _videoMode = widget.initialVideo;
    _publishReel = widget.preferReel;
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _recoverLostGallerySelection();
  }

  // Android can terminate the Activity while a system Photo Picker is open.
  // Recover the returned file if this happens.
  Future<void> _recoverLostGallerySelection() async {
    try {
      final lost = await _picker.retrieveLostData();
      if (_closed || !mounted || lost.isEmpty) return;
      if (lost.exception != null) {
        _showError('Gallery could not restore the selected media.');
        return;
      }
      final files = lost.files;
      if (files != null && files.isNotEmpty) {
        await _acceptGalleryFile(files.first);
      }
    } catch (e) {
      debugPrint('Blink gallery recovery failed: $e');
    }
  }

  Future<void> _disposeCamera(CameraController controller) async {
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
    } catch (error) {
      debugPrint('Blink AR stream stop during cleanup: $error');
    }
    try {
      if (controller.value.isRecordingVideo) {
        await controller.stopVideoRecording();
      }
    } catch (error) {
      debugPrint('Blink camera: stopping video during cleanup: $error');
    }
    try {
      await controller.dispose();
    } catch (error) {
      // Surface cleanup errors must never become unhandled exceptions.
      debugPrint('Blink camera: dispose failed: $error');
    }
  }

  void _queueCameraTask(Future<void> Function() task) {
    _cameraQueue = _cameraQueue.then((_) => task()).catchError(
      (Object error, StackTrace stack) {
        debugPrint('Blink camera lifecycle task: $error\n$stack');
      },
    );
  }

  // Cancel outstanding starts; remove preview first, then dispose.
  void _suspendCamera() {
    ++_cameraGeneration;
    final old = _camera;
    _camera = null;
    if (mounted && !_closed) setState(() {
      _recording = false;
      _faceBounds = null;
    });
    _queueCameraTask(() async {
      if (old != null) await _disposeCamera(old);
    });
  }

  void _initCamera() {
    final generation = ++_cameraGeneration;
    _queueCameraTask(() async {
      // No two native camera operations are allowed to overlap.
      final old = _camera;
      _camera = null;
      if (mounted && !_closed) setState(() {});
      if (old != null) await _disposeCamera(old);

      if (_closed || !mounted || !_appActive || _picked != null ||
          generation != _cameraGeneration) return;

      try {
        if (_cameras.isEmpty) {
          _cameras = await availableCameras();
        }
        if (_cameras.isEmpty) {
          if (mounted && !_closed) {
            setState(() => _cameraError = 'No camera is available on this device.');
          }
          return;
        }
        if (_cameraIndex >= _cameras.length) _cameraIndex = 0;
        if (_closed || !mounted || !_appActive || _picked != null ||
            generation != _cameraGeneration) return;

        final controller = CameraController(
          _cameras[_cameraIndex],
          ResolutionPreset.high,
          enableAudio: true,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
        );
        try {
          await controller.initialize();
          if (_closed || !mounted || !_appActive || _picked != null ||
              generation != _cameraGeneration) {
            await _disposeCamera(controller);
            return;
          }
          await controller.setFlashMode(_flash ? FlashMode.auto : FlashMode.off);
          if (_closed || !mounted || !_appActive || _picked != null ||
              generation != _cameraGeneration) {
            await _disposeCamera(controller);
            return;
          }
          setState(() {
            _camera = controller;
            _cameraError = null;
          });
          if (_lens != 'none' && !_videoMode) {
            unawaited(_startFaceTracking(controller));
          }
        } catch (error) {
          debugPrint('Blink camera initialization failed: $error');
          await _disposeCamera(controller);
          if (mounted && !_closed && _picked == null &&
              generation == _cameraGeneration) {
            setState(() => _cameraError =
                'Camera could not start. Tap Retry or choose Gallery.');
          }
        }
      } catch (error) {
        debugPrint('Blink camera discovery failed: $error');
        if (mounted && !_closed && _picked == null &&
            generation == _cameraGeneration) {
          setState(() => _cameraError =
              'Camera access unavailable. Check permissions and try again.');
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _appActive = false;
      _suspendCamera();
    } else if (state == AppLifecycleState.resumed) {
      _appActive = true;
      if (_picked == null && !_uploading && !_pickerActive) _initCamera();
    }
  }

  static const _orientationDegrees = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Rect _normalizedFace(Rect bounds, double width, double height,
      {bool mirror = false}) {
    if (width <= 0 || height <= 0) return Rect.zero;
    double clamp(double x) => x.clamp(0.0, 1.0);
    final left = mirror ? 1 - bounds.right / width : bounds.left / width;
    final right = mirror ? 1 - bounds.left / width : bounds.right / width;
    return Rect.fromLTRB(
      clamp(left), clamp(bounds.top / height),
      clamp(right), clamp(bounds.bottom / height),
    );
  }

  Future<void> _startFaceTracking(CameraController camera) async {
    if (_lens == 'none' || _videoMode || _picked != null || _closed ||
        !_appActive || camera != _camera || !camera.value.isInitialized ||
        camera.value.isStreamingImages || camera.value.isRecordingVideo) return;
    try {
      await camera.startImageStream((frame) => _detectCameraFace(camera, frame));
    } catch (error) {
      debugPrint('Blink on-device AR detection not available: $error');
    }
  }

  Future<void> _stopFaceTracking(CameraController camera) async {
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } catch (error) {
      debugPrint('Blink AR stream stop: $error');
    }
  }

  Future<void> _detectCameraFace(CameraController camera, CameraImage frame) async {
    if (_processingFace || _lens == 'none' || _videoMode || !_appActive ||
        _picked != null || _closed || camera != _camera) return;
    final now = DateTime.now();
    if (now.difference(_lastFaceFrame).inMilliseconds < 180) return;
    _lastFaceFrame = now;
    final format = InputImageFormatValue.fromRawValue(frame.format.raw);
    if (frame.planes.length != 1 ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return;
    final sensor = _cameras[_cameraIndex].sensorOrientation;
    int rotation = sensor;
    if (Platform.isAndroid) {
      final adjustment = _orientationDegrees[camera.value.deviceOrientation];
      if (adjustment == null) return;
      rotation = _cameras[_cameraIndex].lensDirection == CameraLensDirection.front
          ? (sensor + adjustment) % 360
          : (sensor - adjustment + 360) % 360;
    }
    final orientation = InputImageRotationValue.fromRawValue(rotation);
    if (orientation == null || format == null) return;
    _processingFace = true;
    try {
      final input = InputImage.fromBytes(
        bytes: frame.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: orientation,
          format: format,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
      final faces = await _faceDetector.processImage(input);
      if (!mounted || _closed || camera != _camera || _picked != null ||
          _lens == 'none') return;
      final swap = rotation == 90 || rotation == 270;
      final w = swap ? frame.height.toDouble() : frame.width.toDouble();
      final h = swap ? frame.width.toDouble() : frame.height.toDouble();
      setState(() => _faceBounds = faces.isEmpty ? null : _normalizedFace(
        faces.first.boundingBox, w, h,
        mirror: _cameras[_cameraIndex].lensDirection == CameraLensDirection.front,
      ));
    } catch (error) {
      debugPrint('Blink AR frame detection: $error');
    } finally {
      _processingFace = false;
    }
  }

  Future<void> _detectPhotoFace(XFile file) async {
    if (_lens == 'none' || _videoMode) return;
    try {
      final faces = await _faceDetector.processImage(
        InputImage.fromFilePath(file.path));
      final bytes = await File(file.path).readAsBytes();
      final image = await ui.decodeImageFromList(bytes);
      final rect = faces.isEmpty ? null : _normalizedFace(
        faces.first.boundingBox, image.width.toDouble(), image.height.toDouble());
      image.dispose();
      if (mounted && !_closed && _picked?.path == file.path && _lens != 'none') {
        setState(() => _faceBounds = rect);
      }
    } catch (error) {
      debugPrint('Blink AR photo detection: $error');
    }
  }

  void _selectLens(String lens) {
    if (_uploading || _recording) return;
    setState(() {
      _lens = lens;
      _faceBounds = null;
    });
    final camera = _camera;
    if (camera != null) {
      if (lens == 'none') {
        unawaited(_stopFaceTracking(camera));
      } else if (!_videoMode) {
        unawaited(_startFaceTracking(camera));
      }
    }
    if (_picked != null && !_videoMode && lens != 'none') {
      unawaited(_detectPhotoFace(_picked!));
    }
  }

  void _changeMode(bool video) {
    if (_recording || _uploading || _picked != null) return;
    setState(() {
      _videoMode = video;
      _faceBounds = null;
    });
    final camera = _camera;
    if (camera == null) return;
    if (video) {
      unawaited(_stopFaceTracking(camera));
    } else if (_lens != 'none') {
      unawaited(_startFaceTracking(camera));
    }
  }

  Future<File> _renderFilteredPhoto() async {
    // Composites the exact live emoji artwork visible in the photo preview.
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _mediaBoundary.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw const BlinkHomeError('Could not prepare the AR image.');
    }
    final result = await boundary.toImage(pixelRatio: 2.5);
    try {
      final bytes = await result.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const BlinkHomeError('Could not export the AR image.');
      final dir = await Directory.systemTemp.createTemp('blink_ar_photo_');
      _temporaryMediaDirectories.add(dir);
      final output = File('${dir.path}/blink-ar.png');
      await output.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return output;
    } finally {
      result.dispose();
    }
  }

  Widget _faceEffects() {
    if (_lens == 'none' || _videoMode) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final face = _faceBounds;
      if (face == null) return const SizedBox.shrink();
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final cx = face.center.dx * width;
      final top = face.top * height;
      final faceWidth = face.width * width;
      final size = (faceWidth * 0.62).clamp(42.0, 150.0);
      Widget sticker(String symbol, double x, double y, double factor) =>
        Positioned(
          left: x - size * factor / 2,
          top: y - size * factor / 2,
          child: IgnorePointer(child: Text(symbol,
            style: TextStyle(fontSize: size * factor, shadows: const [
              Shadow(blurRadius: 12, color: Color(0x66000000)),
            ]))),
        );
      switch (_lens) {
        case 'cat':
          return Stack(children: [
            sticker('🐱', cx, top - size * .25, 1.1),
          ]);
        case 'dog':
          return Stack(children: [
            sticker('🐶', cx, top - size * .24, 1.1),
          ]);
        case 'butterfly':
          return Stack(children: [
            sticker('🦋', cx - faceWidth * .5, top + size * .35, .85),
            sticker('🦋', cx + faceWidth * .5, top + size * .35, .85),
          ]);
        case 'heart':
          return Stack(children: [
            sticker('💖', cx, top - size * .45, .9),
            sticker('✨', cx + faceWidth * .42, top + size * .2, .48),
          ]);
        case 'crown':
          return Stack(children: [sticker('👑', cx, top - size * .3, 1.3)]);
        case 'glasses':
          return Stack(children: [sticker('😎', cx, top + size * .43, .95)]);
        case 'cyber':
          return Stack(children: [
            sticker('⚡', cx - faceWidth * .52, top + size * .18, .85),
            sticker('⚡', cx + faceWidth * .52, top + size * .18, .85),
          ]);
        case 'blush':
          return Stack(children: [
            sticker('🌸', cx - faceWidth * .33, top + size * .93, .5),
            sticker('🌸', cx + faceWidth * .33, top + size * .93, .5),
          ]);
        case 'party':
          return Stack(children: [
            sticker('🎉', cx, top - size * .37, 1.1),
            sticker('✨', cx + faceWidth * .5, top + size * .3, .55),
          ]);
      }
      return const SizedBox.shrink();
    });
  }

  Widget _lensPicker() => SizedBox(
    height: 72,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      scrollDirection: Axis.horizontal,
      itemCount: _lenses.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final entry = _lenses[index];
        final chosen = _lens == entry.$1;
        return InkWell(
          onTap: () => _selectLens(entry.$1),
          borderRadius: BorderRadius.circular(17),
          child: Container(
            width: 69, alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: chosen ? BlinkColors.orange : const Color(0xB0171719),
              border: Border.all(color: chosen ? Colors.white : Colors.white38),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(entry.$2, style: const TextStyle(color: Colors.white, fontSize: 25)),
              const SizedBox(height: 4),
              Text(entry.$3, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white,
                  fontSize: 9, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      },
    ),
  );

  Future<void> _switchCamera() async {
    if (_recording || _uploading || _picked != null || _cameras.length < 2) {
      return;
    }
    setState(() => _cameraIndex = (_cameraIndex + 1) % _cameras.length);
    _initCamera();
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _recording) return;
    try {
      final on = !_flash;
      await camera.setFlashMode(on ? FlashMode.auto : FlashMode.off);
      if (mounted) setState(() => _flash = on);
    } catch (e) {
      _showError('Flash unavailable: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Determine the media type from the actual selected file, never from the
  // current Photo/Video toggle. The system picker can return either format.
  Future<void> _acceptGalleryFile(XFile selected) async {
    final lowerName = selected.name.toLowerCase();
    final lowerPath = selected.path.toLowerCase();
    final mime = (selected.mimeType ?? '').toLowerCase();
    bool matches(String extension) =>
        lowerName.endsWith(extension) || lowerPath.endsWith(extension);

    final isVideo = mime.startsWith('video/') ||
        ['.mp4', '.mov', '.webm'].any(matches);
    final isImage = mime.startsWith('image/') ||
        ['.jpg', '.jpeg', '.png', '.webp', '.gif'].any(matches);

    if (!isVideo && !isImage) {
      throw const BlinkHomeError(
        'Unsupported gallery file. Choose JPG, PNG, WebP, GIF, MP4, MOV or WebM.',
      );
    }

    // The backend explicitly accepts only these types. In particular, HEIC,
    // HEIF, AVI and MKV cannot be uploaded without transcoding.
    final extension = isVideo
        ? (matches('.mov') ? '.mov' : matches('.webm') ? '.webm' :
            matches('.mp4') || mime == 'video/mp4' ? '.mp4' :
            mime == 'video/quicktime' ? '.mov' : mime == 'video/webm' ? '.webm' : '')
        : (matches('.jpeg') || matches('.jpg') || mime == 'image/jpeg' ? '.jpg'
            : matches('.png') || mime == 'image/png' ? '.png'
            : matches('.webp') || mime == 'image/webp' ? '.webp'
            : matches('.gif') || mime == 'image/gif' ? '.gif' : '');

    if (extension.isEmpty) {
      throw const BlinkHomeError(
        'This media format is not supported by the Blink server. '
        'Please select a JPG/PNG photo or MP4/MOV/WebM video.',
      );
    }

    // System picker output may reside in a temporary ContentProvider cache.
    // Copy it to Blink's own temporary directory before preview/upload.
    final temporaryDir = await Directory.systemTemp.createTemp('blink_gallery_');
    _temporaryMediaDirectories.add(temporaryDir);
    final safePath = '${temporaryDir.path}/selected$extension';
    await selected.saveTo(safePath);
    final safeFile = File(safePath);
    if (!await safeFile.exists() || await safeFile.length() == 0) {
      throw const BlinkHomeError('The selected gallery file is empty or unavailable.');
    }
    if (_closed || !mounted) return;
    await _selectFile(XFile(safePath), video: isVideo);
  }

  Future<void> _gallery() async {
    if (_recording || _uploading || _pickerActive) return;
    _pickerActive = true;
    // Release CameraPreview completely before the Android picker steals focus.
    _suspendCamera();
    try {
      await _cameraQueue;
      if (_closed || !mounted) return;
      final selected = await _picker.pickMedia(requestFullMetadata: false);
      if (selected != null && mounted && !_closed) {
        await _acceptGalleryFile(selected);
      }
    } on PlatformException catch (e) {
      _showError('Gallery selection failed: ${e.message ?? e.code}');
    } on BlinkHomeError catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unable to open selected gallery media: $e');
    } finally {
      _pickerActive = false;
      if (mounted && !_closed && _picked == null && _appActive) {
        _initCamera();
      }
    }
  }

  Future<void> _shoot() async {
    final camera = _camera;
    if (_uploading || camera == null || !camera.value.isInitialized) return;
    try {
      // CameraX cannot reliably take still photographs while the analysis
      // image stream is active. Freeze the last face position before capture.
      if (camera.value.isStreamingImages) await _stopFaceTracking(camera);
      if (_videoMode) {
        if (_recording) {
          final video = await camera.stopVideoRecording();
          if (mounted) setState(() => _recording = false);
          await _selectFile(video, video: true);
        } else {
          await camera.startVideoRecording();
          if (mounted) setState(() => _recording = true);
        }
      } else {
        final photo = await camera.takePicture();
        await _selectFile(photo, video: false);
      }
    } catch (e) {
      if (mounted) setState(() => _recording = false);
      _showError('Capture failed: $e');
    }
  }

  Future<void> _selectFile(XFile file, {required bool video}) async {
    if (!mounted || _closed) return;
    setState(() {
      _picked = file;
      _videoMode = video;
      _publishReel = video;
      _recording = false;
      _error = null;
    });
    // Hide CameraPreview before releasing the native camera surface.
    _suspendCamera();
    if (!video && _lens != 'none') {
      unawaited(_detectPhotoFace(file));
    }

    final previousPreview = _preview;
    _preview = null;
    if (previousPreview != null) await previousPreview.dispose();

    if (video) {
      final controller = VideoPlayerController.file(File(file.path));
      try {
        await controller.initialize();
        if (!mounted || _closed || _picked?.path != file.path) {
          await controller.dispose();
          return;
        }
        await controller.setLooping(true);
        await controller.play();
        if (!mounted || _closed) {
          await controller.dispose();
          return;
        }
        setState(() => _preview = controller);
      } catch (error) {
        await controller.dispose();
        _showError('Cannot preview selected video. Please choose another file.');
        debugPrint('Blink video preview failed: $error');
      }
    }
  }

  Future<void> _discard() async {
    if (_uploading) return;
    final oldPreview = _preview;
    _preview = null;
    if (oldPreview != null) await oldPreview.dispose();
    if (!mounted || _closed) return;
    _caption.clear();
    await _soundtrackPlayer.stop();
    setState(() {
      _soundtrackPlaying = false;
      _musicTrackId = null;
      _picked = null;
      _error = null;
      _faceBounds = null;
      _recording = false;
    });
    if (_appActive) _initCamera();
  }

  Future<void> _previewSoundtrack() async {
    final selected = _musicTrackId;
    if (selected == null) return;
    try {
      await _soundtrackPlayer.play(selected);
      if (mounted) setState(() {
        _soundtrackPlaying = _soundtrackPlayer.isPlaying;
      });
    } catch (error) {
      _showError('Soundtrack preview failed: $error');
    }
  }

  Future<void> _publish() async {
    if (_picked == null || _uploading) return;
    setState(() { _uploading = true; _error = null; });
    await _soundtrackPlayer.stop();
    try {
      final file = !_videoMode && _lens != 'none'
          ? await _renderFilteredPhoto() : File(_picked!.path);
      if (_videoMode && _publishReel) {
        final Uint8List jpeg =
        await thumb.VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: thumb_format.ImageFormat.JPEG,
          maxWidth: 720,
          quality: 80,
        );
        if (jpeg.isEmpty) {
          throw const BlinkHomeError('Cannot generate JPEG cover from this video. Choose a playable MP4 or MOV.');
        }
        await BlinkHomeApi.uploadReel(file, jpeg, caption: _caption.text);
      } else {
        await BlinkHomeApi.uploadMoment(file, caption: _caption.text, musicTrackId: _musicTrackId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_videoMode && _publishReel ? 'Reel published!' : 'Moment published!'),
        backgroundColor: BlinkColors.orangeDark,
      ));
      // Fresh Home route fetches the updated database-backed feed.
      go(context, _videoMode && _publishReel ? '/reels' : '/home', replace: true);
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closed = true;
    _appActive = false;
    ++_cameraGeneration;
    final old = _camera;
    _camera = null;
    _queueCameraTask(() async {
      if (old != null) await _disposeCamera(old);
    });
    _preview?.dispose();
    _soundtrackPlayer.dispose();
    unawaited(_faceDetector.close());
    _caption.dispose();
    for (final dir in _temporaryMediaDirectories) {
      dir.delete(recursive: true).ignore();
    }
    super.dispose();
  }

  Widget _background() {
    final file = _picked;
    if (file != null) {
      if (_videoMode) {
        final video = _preview;
        if (video != null && video.value.isInitialized) {
          return Center(child: AspectRatio(
            aspectRatio: video.value.aspectRatio,
            child: VideoPlayer(video),
          ));
        }
        return const Center(child: Text('Video preview unavailable', style: TextStyle(color: Colors.white)));
      }
      return Image.file(File(file.path), fit: BoxFit.contain, width: double.infinity, height: double.infinity);
    }
    final camera = _camera;
    if (camera != null && camera.value.isInitialized) {
      return CameraPreview(camera);
    }
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_cameraError ?? 'Preparing camera...',
          style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        if (_cameraError != null) ...[
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: _appActive && !_uploading ? _initCamera : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry camera'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ]),
    ));
  }

  Widget _modeButton(String title, bool selected, bool left, VoidCallback pressed) {
    return GestureDetector(onTap: pressed, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 11),
      decoration: BoxDecoration(
        color: selected ? BlinkColors.orange : Colors.white60,
        borderRadius: BorderRadius.horizontal(
          left: left ? const Radius.circular(24) : Radius.zero,
          right: !left ? const Radius.circular(24) : Radius.zero,
        ),
      ),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12,
        color: selected ? Colors.white : BlinkColors.ink)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _picked != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: RepaintBoundary(
          key: _mediaBoundary,
          child: Stack(fit: StackFit.expand, children: [
            _background(),
            if (_lens != 'none' && !_videoMode) _faceEffects(),
          ]),
        )),
        Positioned.fill(child: IgnorePointer(child: Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x55000000), Colors.transparent, Color(0xAA000000)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        )))),
        SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            IconButton(onPressed: _uploading ? null : () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 29)),
            const Spacer(),
            const BlinkLogo(fontSize: 26),
            const Spacer(),
            if (!preview) IconButton(onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white)),
          ])),
          if (!_videoMode && !_recording) _lensPicker(),
          const Spacer(),
          if (preview) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 17), child: TextField(
              controller: _caption,
              maxLength: _videoMode && _publishReel ? 1000 : 500,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0x99000000),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )),
            if (!_videoMode || !_publishReel) Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFF242424),
                ),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_musicTrackId ?? 'none'),
                  initialValue: _musicTrackId ?? '',
                  isExpanded: true,
                  dropdownColor: const Color(0xFF242424),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '🎵 Blink Original soundtrack',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xCC191919),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem(value: '', child: Text('🔇 No music')),
                    ..._soundtracks.entries.map(
                      (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: _uploading ? null : (value) {
                    _soundtrackPlayer.stop();
                    setState(() {
                      _soundtrackPlaying = false;
                      _musicTrackId = value == null || value.isEmpty ? null : value;
                    });
                  },
                ),
              ),
            ),
            if (_musicTrackId != null && (!_videoMode || !_publishReel))
              Padding(padding: const EdgeInsets.only(bottom: 8),
                child: TextButton.icon(
                  onPressed: _uploading ? null : _previewSoundtrack,
                  icon: Icon(_soundtrackPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    color: Colors.white),
                  label: Text(_soundtrackPlaying ? 'Stop original music preview' : 'Preview original music',
                    style: const TextStyle(color: Colors.white)),
                )),
            if (_videoMode) Padding(padding: const EdgeInsets.only(bottom: 10), child: Wrap(spacing: 9, children: [
              ChoiceChip(label: const Text('Reel'), selected: _publishReel,
                onSelected: _uploading ? null : (_) => setState(() => _publishReel = true)),
              ChoiceChip(label: const Text('Moment'), selected: !_publishReel,
                onSelected: _uploading ? null : (_) => setState(() => _publishReel = false)),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _uploading ? null : _discard,
                icon: const Icon(Icons.replay_rounded), label: const Text('Retake'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(onPressed: _uploading ? null : _publish,
                icon: _uploading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_uploading ? 'Uploading...' : 'Publish'),
                style: FilledButton.styleFrom(backgroundColor: BlinkColors.orange))),
            ])),
          ] else ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _modeButton('Photo', !_videoMode, true, () => _changeMode(false)),
              _modeButton('Video', _videoMode, false, () => _changeMode(true)),
            ]),
            const SizedBox(height: 25),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(onPressed: _pickerActive ? null : _gallery, icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28)),
              GestureDetector(onTap: _shoot, child: Container(
                width: 78, height: 78, padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: _recording ? Colors.red : Colors.white, width: 4)),
                child: CircleAvatar(backgroundColor: _recording ? Colors.red : BlinkColors.orange,
                  child: Icon(_recording ? Icons.stop_rounded : (_videoMode ? Icons.videocam_rounded : Icons.camera_alt_rounded), color: Colors.white)),
              )),
              IconButton(onPressed: _toggleFlash,
                icon: Icon(_flash ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white, size: 28)),
            ]),
            const SizedBox(height: 19),
            Text(_recording ? 'Recording… tap again to stop' : (_videoMode ? 'Tap to start recording' : 'Tap to capture'),
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.all(12),
            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))),
          const SizedBox(height: 20),
        ])),
      ]),
    );
  }
}
