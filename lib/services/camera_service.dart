import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

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
        debugPrint('[CameraService] No cameras available on this device.');
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
      debugPrint('[CameraService] Camera initialized: ${backCamera.name}');
    } catch (e) {
      debugPrint('[CameraService] Init error: $e');
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
      debugPrint('[CameraService] Capture error: $e');
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
      debugPrint('[CameraService] Base64 encode error: $e');
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
