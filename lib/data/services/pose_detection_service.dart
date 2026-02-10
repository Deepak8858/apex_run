/// Camera-based pose detection service using Google ML Kit
/// Bridges the camera stream to the GaitMetricsCalculator for real-time
/// running form analysis via MediaPipe's 33-landmark BlazePose model.
library;
import 'dart:async';
import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;
import '../../ml/gait_metrics_calculator.dart';

/// Service that processes camera frames through ML Kit pose detection
/// and feeds the results to the GaitMetricsCalculator.
class PoseDetectionService {
  final GaitMetricsCalculator _calculator;
  CameraController? _cameraController;
  mlkit.PoseDetector? _poseDetector;
  bool _isProcessing = false;
  bool _isInitialized = false;
  int _frameCount = 0;
  final int _processEveryNFrames;

  final _progressController =
      StreamController<PoseDetectionProgress>.broadcast();

  Stream<PoseDetectionProgress> get progressStream =>
      _progressController.stream;
  bool get isInitialized => _isInitialized;
  GaitMetricsCalculator get calculator => _calculator;

  PoseDetectionService({
    GaitMetricsCalculator? calculator,
    int processEveryNFrames = 2, // Process every 2nd frame for performance
  })  : _calculator = calculator ?? GaitMetricsCalculator(),
        _processEveryNFrames = processEveryNFrames;

  /// Initialize camera and pose detector
  Future<CameraController?> initialize() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('PoseDetection: No cameras available');
        return null;
      }

      // Prefer front camera for self-facing form analysis
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Initialize camera controller
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      // Initialize ML Kit Pose Detector with BlazePose accuracy model
      final options = mlkit.PoseDetectorOptions(
        mode: mlkit.PoseDetectionMode.stream,
        model: mlkit.PoseDetectionModel.accurate,
      );
      _poseDetector = mlkit.PoseDetector(options: options);

      _isInitialized = true;
      debugPrint('PoseDetection: Initialized successfully');
      return _cameraController;
    } catch (e) {
      debugPrint('PoseDetection: Initialization failed: $e');
      return null;
    }
  }

  /// Start processing camera frames for pose detection
  Future<void> startProcessing() async {
    if (!_isInitialized || _cameraController == null) return;

    _frameCount = 0;
    _calculator.reset();

    await _cameraController!.startImageStream((CameraImage image) {
      _frameCount++;
      // Skip frames for performance
      if (_frameCount % _processEveryNFrames != 0) return;
      if (_isProcessing) return;

      _processFrame(image);
    });
  }

  /// Process a single camera frame
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final landmarks = _convertLandmarks(pose);

        _calculator.addPoseFrame(
          landmarks: landmarks,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          confidence: _averageConfidence(pose),
        );

        _progressController.add(PoseDetectionProgress(
          framesProcessed: _frameCount ~/ _processEveryNFrames,
          landmarksDetected: pose.landmarks.length,
          hasEnoughData: _calculator.hasEnoughData,
          currentFormScore:
              _calculator.hasEnoughData ? _calculator.calculateFormScore() : null,
        ));
      }
    } catch (e) {
      debugPrint('PoseDetection: Frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Convert CameraImage to ML Kit InputImage
  mlkit.InputImage? _convertCameraImage(CameraImage image) {
    try {
      final rotation = _getRotation();
      if (rotation == null) return null;

      final format = mlkit.InputImageFormatValue.fromRawValue(
        image.format.raw as int,
      );
      if (format == null) return null;

      final plane = image.planes.first;

      return mlkit.InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: mlkit.InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get input image rotation from camera sensor orientation
  mlkit.InputImageRotation? _getRotation() {
    if (_cameraController == null) return null;
    final sensorOrientation =
        _cameraController!.description.sensorOrientation;
    switch (sensorOrientation) {
      case 0:
        return mlkit.InputImageRotation.rotation0deg;
      case 90:
        return mlkit.InputImageRotation.rotation90deg;
      case 180:
        return mlkit.InputImageRotation.rotation180deg;
      case 270:
        return mlkit.InputImageRotation.rotation270deg;
      default:
        return mlkit.InputImageRotation.rotation0deg;
    }
  }

  /// Convert ML Kit PoseLandmarks to our PoseLandmark model
  List<PoseLandmark> _convertLandmarks(mlkit.Pose pose) {
    return pose.landmarks.values.map((landmark) {
      return PoseLandmark(
        x: landmark.x,
        y: landmark.y,
        z: landmark.z,
      );
    }).toList();
  }

  /// Calculate average confidence from all landmarks
  double _averageConfidence(mlkit.Pose pose) {
    if (pose.landmarks.isEmpty) return 0;
    final total = pose.landmarks.values
        .fold<double>(0, (sum, l) => sum + l.likelihood);
    return total / pose.landmarks.length;
  }

  /// Stop processing
  Future<void> stopProcessing() async {
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await stopProcessing();
    await _cameraController?.dispose();
    await _poseDetector?.close();
    await _progressController.close();
    _isInitialized = false;
  }
}

/// Progress update from pose detection processing
class PoseDetectionProgress {
  final int framesProcessed;
  final int landmarksDetected;
  final bool hasEnoughData;
  final int? currentFormScore;

  const PoseDetectionProgress({
    required this.framesProcessed,
    required this.landmarksDetected,
    required this.hasEnoughData,
    this.currentFormScore,
  });
}
