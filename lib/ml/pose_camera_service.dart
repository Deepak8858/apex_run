import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;
import 'gait_metrics_calculator.dart';

/// PoseCameraService — Bridges Camera → MediaPipe → FormAnalyzer
///
/// This is the critical missing link in Phase 5. It:
/// 1. Opens the device camera
/// 2. Streams frames to Google ML Kit Pose Detection (MediaPipe BlazePose)
/// 3. Converts ML Kit PoseLandmark → app PoseLandmark
/// 4. Emits landmarks via a stream for consumption by FormAnalyzer
class PoseCameraService {
  CameraController? _cameraController;
  mlkit.PoseDetector? _poseDetector;
  bool _isProcessing = false;
  bool _isRunning = false;

  final StreamController<PoseFrame> _poseStreamController =
      StreamController<PoseFrame>.broadcast();

  /// Stream of pose detection results
  Stream<PoseFrame> get poseStream => _poseStreamController.stream;

  /// Whether the camera + detection pipeline is active
  bool get isRunning => _isRunning;

  /// The camera controller (for UI preview)
  CameraController? get cameraController => _cameraController;

  /// Initialize and start the camera + pose detection pipeline
  ///
  /// [cameraLensDirection] — front or back camera (default: front for treadmill)
  Future<void> start({
    CameraLensDirection cameraLensDirection = CameraLensDirection.front,
  }) async {
    if (_isRunning) return;

    // Initialize ML Kit Pose Detector
    _poseDetector = mlkit.PoseDetector(
      options: mlkit.PoseDetectorOptions(
        model: mlkit.PoseDetectionModel.accurate,
        mode: mlkit.PoseDetectionMode.stream,
      ),
    );

    // Find and initialize camera
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == cameraLensDirection,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium, // Balance quality vs. performance
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );

    await _cameraController!.initialize();

    // Lock orientation for consistent landmark coordinates
    await _cameraController!.lockCaptureOrientation(
      DeviceOrientation.portraitUp,
    );

    _isRunning = true;

    // Start streaming frames
    await _cameraController!.startImageStream(_processImage);

    debugPrint('PoseCameraService: Pipeline started '
        '(${camera.lensDirection.name} camera, '
        '${_cameraController!.value.previewSize})');
  }

  /// Stop the camera and detection pipeline
  Future<void> stop() async {
    _isRunning = false;

    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }

    await _poseDetector?.close();
    _poseDetector = null;

    debugPrint('PoseCameraService: Pipeline stopped');
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await stop();
    _poseStreamController.close();
  }

  /// Process a single camera image through pose detection
  void _processImage(CameraImage image) {
    if (!_isRunning || _isProcessing || _poseDetector == null) return;
    _isProcessing = true;

    _detectPose(image).then((frame) {
      if (frame != null && !_poseStreamController.isClosed) {
        _poseStreamController.add(frame);
      }
    }).catchError((e) {
      debugPrint('PoseCameraService: Detection error: $e');
    }).whenComplete(() {
      _isProcessing = false;
    });
  }

  /// Run ML Kit pose detection on a camera image
  Future<PoseFrame?> _detectPose(CameraImage image) async {
    final inputImage = _buildInputImage(image);
    if (inputImage == null) return null;

    final poses = await _poseDetector!.processImage(inputImage);
    if (poses.isEmpty) return null;

    // Take the most prominent pose (first detected)
    final pose = poses.first;
    final timestampMs = DateTime.now().millisecondsSinceEpoch;

    // Convert ML Kit landmarks → app PoseLandmark
    final landmarks = _convertLandmarks(pose);
    if (landmarks.length < 33) return null;

    // Calculate overall confidence as mean of all landmark likelihoods
    double totalConfidence = 0;
    int count = 0;
    for (final lm in pose.landmarks.values) {
      totalConfidence += lm.likelihood;
      count++;
    }
    final avgConfidence = count > 0 ? totalConfidence / count : 0.0;

    return PoseFrame(
      landmarks: landmarks,
      timestampMs: timestampMs,
      confidence: avgConfidence,
      mlkitPose: pose,
    );
  }

  /// Convert ML Kit PoseLandmark → app PoseLandmark (indexed 0-32)
  List<PoseLandmark> _convertLandmarks(mlkit.Pose pose) {
    // ML Kit BlazePose has 33 landmarks indexed by PoseLandmarkType
    // We need them in order 0-32 matching our GaitMetricsCalculator
    final orderedTypes = [
      mlkit.PoseLandmarkType.nose, // 0
      mlkit.PoseLandmarkType.leftEyeInner, // 1
      mlkit.PoseLandmarkType.leftEye, // 2
      mlkit.PoseLandmarkType.leftEyeOuter, // 3
      mlkit.PoseLandmarkType.rightEyeInner, // 4
      mlkit.PoseLandmarkType.rightEye, // 5
      mlkit.PoseLandmarkType.rightEyeOuter, // 6
      mlkit.PoseLandmarkType.leftEar, // 7
      mlkit.PoseLandmarkType.rightEar, // 8
      mlkit.PoseLandmarkType.leftMouth, // 9
      mlkit.PoseLandmarkType.rightMouth, // 10
      mlkit.PoseLandmarkType.leftShoulder, // 11
      mlkit.PoseLandmarkType.rightShoulder, // 12
      mlkit.PoseLandmarkType.leftElbow, // 13
      mlkit.PoseLandmarkType.rightElbow, // 14
      mlkit.PoseLandmarkType.leftWrist, // 15
      mlkit.PoseLandmarkType.rightWrist, // 16
      mlkit.PoseLandmarkType.leftPinky, // 17
      mlkit.PoseLandmarkType.rightPinky, // 18
      mlkit.PoseLandmarkType.leftIndex, // 19
      mlkit.PoseLandmarkType.rightIndex, // 20
      mlkit.PoseLandmarkType.leftThumb, // 21
      mlkit.PoseLandmarkType.rightThumb, // 22
      mlkit.PoseLandmarkType.leftHip, // 23
      mlkit.PoseLandmarkType.rightHip, // 24
      mlkit.PoseLandmarkType.leftKnee, // 25
      mlkit.PoseLandmarkType.rightKnee, // 26
      mlkit.PoseLandmarkType.leftAnkle, // 27
      mlkit.PoseLandmarkType.rightAnkle, // 28
      mlkit.PoseLandmarkType.leftHeel, // 29
      mlkit.PoseLandmarkType.rightHeel, // 30
      mlkit.PoseLandmarkType.leftFootIndex, // 31
      mlkit.PoseLandmarkType.rightFootIndex, // 32
    ];

    final landmarks = <PoseLandmark>[];
    final imageWidth = _cameraController?.value.previewSize?.width ?? 1;
    final imageHeight = _cameraController?.value.previewSize?.height ?? 1;

    for (final type in orderedTypes) {
      final lm = pose.landmarks[type];
      if (lm == null) {
        landmarks.add(const PoseLandmark(x: 0, y: 0, z: 0));
      } else {
        // Normalize to [0, 1] range
        landmarks.add(PoseLandmark(
          x: lm.x / imageWidth,
          y: lm.y / imageHeight,
          z: lm.z,
        ));
      }
    }

    return landmarks;
  }

  /// Build ML Kit InputImage from CameraImage
  InputImage? _buildInputImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final rotation = _rotationFromSensorOrientation(camera.sensorOrientation);

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android: NV21 format
      final bytes = _concatenatePlanes(image.planes);
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );
      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS: BGRA8888 format
      final bytes = image.planes[0].bytes;
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      );
      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    }

    return null;
  }

  /// Concatenate NV21 image planes into a single byte array
  Uint8List _concatenatePlanes(List<Plane> planes) {
    int totalSize = 0;
    for (final plane in planes) {
      totalSize += plane.bytes.length;
    }

    final result = Uint8List(totalSize);
    int offset = 0;
    for (final plane in planes) {
      result.setAll(offset, plane.bytes);
      offset += plane.bytes.length;
    }

    return result;
  }

  /// Map sensor orientation to ML Kit rotation
  InputImageRotation _rotationFromSensorOrientation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}

/// A single frame of pose detection results
class PoseFrame {
  final List<PoseLandmark> landmarks;
  final int timestampMs;
  final double confidence;
  final mlkit.Pose mlkitPose;

  const PoseFrame({
    required this.landmarks,
    required this.timestampMs,
    required this.confidence,
    required this.mlkitPose,
  });
}
