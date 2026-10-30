import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:get_video_thumbnail/get_video_thumbnail.dart' as thumb;
import 'package:get_video_thumbnail/index.dart' as thumb_format;

import '../core/blink_home_api.dart';
import '../core/nav.dart';
import '../core/theme.dart';

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
  List<CameraDescription> _cameras = [];
  CameraController? _camera;
  VideoPlayerController? _preview;
  XFile? _picked;
  late bool _videoMode;
  bool _recording = false;
  bool _uploading = false;
  bool _flash = false;
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
    if (mounted && !_closed) setState(() => _recording = false);
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
          imageFormatGroup: ImageFormatGroup.jpeg,
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
    setState(() {
      _picked = null;
      _error = null;
      _recording = false;
    });
    if (_appActive) _initCamera();
  }

  Future<void> _publish() async {
    if (_picked == null || _uploading) return;
    setState(() { _uploading = true; _error = null; });
    try {
      final file = File(_picked!.path);
      if (_videoMode && _publishReel) {
        final Uint8List jpeg =
        await thumb.VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: thumb_format.ImageFormat.JPEG,
          maxWidth: 720,
          quality: 80,
        );
        if (jpeg == null || jpeg.isEmpty) {
          throw const BlinkHomeError('Cannot generate JPEG cover from this video. Choose a playable MP4 or MOV.');
        }
        await BlinkHomeApi.uploadReel(file, jpeg, caption: _caption.text);
      } else {
        await BlinkHomeApi.uploadMoment(file, caption: _caption.text);
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
    _caption.dispose();
    for (final dir in _temporaryMediaDirectories) {
      dir.delete(recursive: true).catchError((Object _) {});
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
        Positioned.fill(child: _background()),
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
            if (!preview) IconButton(onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white)),
          ])),
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
              _modeButton('Photo', !_videoMode, true, () { if (!_recording) setState(() => _videoMode = false); }),
              _modeButton('Video', _videoMode, false, () { if (!_recording) setState(() => _videoMode = true); }),
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
