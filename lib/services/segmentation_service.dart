// lib/services/segmentation_service.dart
//
// ML-powered background removal using native platform APIs.
// iOS: Apple Vision Framework (VNGenerateForegroundInstanceMaskRequest)
// Android: Google ML Kit Subject Segmentation
//
// Falls back gracefully when native segmentation is unavailable.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:native_cutout/native_cutout.dart';
import 'package:path_provider/path_provider.dart';

/// Service that wraps native_cutout for ML-powered background removal.
/// Provides remove.bg-quality segmentation using on-device AI models.
class SegmentationService {
  static final SegmentationService _instance = SegmentationService._internal();
  factory SegmentationService() => _instance;
  SegmentationService._internal();

  bool _isModelReady = false;
  bool _isInitializing = false;
  bool _initAttempted = false;

  /// Whether native ML segmentation is available on this device.
  bool get isAvailable => _isModelReady;

  /// Whether initialization has been attempted (may have failed).
  bool get initAttempted => _initAttempted;

  /// Stream of model download progress (Android only).
  /// On iOS, the model is built-in and this stream is empty.
  Stream<ModelDownloadProgress> get downloadProgress =>
      NativeCutout.downloadProgress;

  /// Initialize the segmentation engine.
  /// On Android, checks if the ML Kit model is available and downloads it if not.
  /// On iOS, the Vision Framework is always available (iOS 17+).
  Future<void> initialize({
    void Function(String status, double progress)? onProgress,
  }) async {
    if (_isModelReady || _isInitializing) return;
    _isInitializing = true;

    try {
      // Check if the native model is available
      final isReady = await NativeCutout.isModelAvailable();

      if (!isReady) {
        onProgress?.call('Downloading AI segmentation model...', 0.0);
        debugPrint('SegmentationService: ML model not available, downloading...');

        final downloaded = await NativeCutout.downloadModel();
        if (!downloaded) {
          debugPrint('SegmentationService: ML model download failed');
          _initAttempted = true;
          return;
        }

        debugPrint('SegmentationService: ML model downloaded successfully');
      }

      _isModelReady = true;
      onProgress?.call('AI segmentation ready', 1.0);
      debugPrint('SegmentationService: initialized successfully');
    } catch (e) {
      debugPrint('SegmentationService: initialization error: $e');
    } finally {
      _isInitializing = false;
      _initAttempted = true;
    }
  }

  /// Segment the foreground subject from the background.
  ///
  /// Takes raw image bytes, returns a transparent PNG with the background
  /// removed, or null if segmentation fails.
  ///
  /// The native_cutout plugin requires a file path input, so this method
  /// writes the bytes to a temporary file, processes it, then cleans up.
  Future<Uint8List?> segment(Uint8List imageBytes) async {
    if (!_isModelReady) {
      debugPrint('SegmentationService: not ready, attempting late init...');
      await initialize();
      if (!_isModelReady) return null;
    }

    File? tempFile;
    try {
      // Write input bytes to a temporary file (native_cutout needs a file path)
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      tempFile = File('${tempDir.path}/seg_input_$timestamp.png');
      await tempFile.writeAsBytes(imageBytes);

      // Run native ML segmentation
      final result = await NativeCutout.removeBackground(
        tempFile.path,
        options: const CutoutOptions(
          cropToSubject: false, // Keep original canvas size for mask alignment
          writeToCache: false, // Return bytes directly
        ),
      );

      switch (result) {
        case CutoutBytesSuccess(:final pngBytes):
          debugPrint('SegmentationService: segmentation succeeded (${pngBytes.length} bytes)');
          return pngBytes;
        case CutoutFileSuccess(:final path):
          // Shouldn't happen with writeToCache: false, but handle it
          debugPrint('SegmentationService: got file result, reading...');
          final file = File(path);
          return await file.readAsBytes();
        case CutoutFailure(:final code, :final message):
          debugPrint('SegmentationService: segmentation failed: ${code.name} - $message');
          return null;
      }
    } catch (e) {
      debugPrint('SegmentationService: error during segmentation: $e');
      return null;
    } finally {
      // Clean up the temp input file
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  /// Clear any cached segmentation outputs.
  Future<void> clearCache() async {
    try {
      await NativeCutout.clearCache();
    } catch (_) {}
  }
}
