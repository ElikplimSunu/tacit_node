import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import '../utils/logger.dart';

/// Wraps the camera lifecycle — init, preview, frame capture.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _cameras.isNotEmpty;

  /// Discover available cameras and initialize the back camera.
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        TLog.warn('No cameras available on this device.');
        return;
      }

      // Prefer back camera for field inspection
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
      TLog.info('Camera initialized: ${backCamera.name}');
    } catch (e) {
      TLog.error('Camera init error: $e');
      _isInitialized = false;
    }
  }

  /// Captures a single frame, returns the file path.
  Future<String?> captureFrame() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      final file = await _controller!.takePicture();
      return file.path;
    } catch (e) {
      TLog.error('Capture error: $e');
      return null;
    }
  }

  /// Captures a frame and returns it as a base64-encoded JPEG string.
  Future<String?> captureFrameAsBase64() async {
    final path = await captureFrame();
    if (path == null) return null;
    try {
      final bytes = await File(path).readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      TLog.error('Base64 encode error: $e');
      return null;
    }
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
