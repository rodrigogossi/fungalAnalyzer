import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/detection_models.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const _inputSize = 1024;
const _maskSize = 256;
const _numClasses = 2;
const _numMaskCoeff = 32;
const _numFeatures = 4 + _numClasses + _numMaskCoeff; // 38
const _confidenceThreshold = 0.50;

// ─── Public API ──────────────────────────────────────────────────────────────

class FungalDetector extends ChangeNotifier {
  bool get isModelLoaded => _modelBytes != null;
  bool _warmedUp = false;
  bool get isWarmedUp => _warmedUp;

  Uint8List? _modelBytes;

  FungalDetector() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      final byteData = await rootBundle.load('assets/models/best_float32.tflite');
      _modelBytes = byteData.buffer.asUint8List();
      notifyListeners();
      _warmUp();
    } catch (e) {
      debugPrint('⚠️ Modelo não encontrado: $e');
    }
  }

  void _warmUp() async {
    if (_modelBytes == null) return;
    await Future.delayed(Duration.zero);
    try {
      final bytes = _modelBytes!;
      await Isolate.run(() => _runInference(bytes,
          Uint8List(_inputSize * _inputSize * 3), isWarmUp: true));
      _warmedUp = true;
      notifyListeners();
      debugPrint('🔥 Modelo pronto.');
    } catch (e) {
      debugPrint('Warm-up error: $e');
    }
  }

  Future<AnalysisResult> detect(Uint8List imageBytes) async {
    if (_modelBytes == null) throw Exception('Modelo não carregado.');
    final bytes = _modelBytes!;
    final rgbPixels = await Isolate.run(() => _preprocessImage(imageBytes));
    return await Isolate.run(() => _runInference(bytes, rgbPixels));
  }
}

// ─── Preprocessing (runs in isolate) ─────────────────────────────────────────

Uint8List _preprocessImage(Uint8List imageBytes) {
  final original = img.decodeImage(imageBytes)!;
  final resized = img.copyResize(original,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear);
  final out = Uint8List(_inputSize * _inputSize * 3);
  int idx = 0;
  for (int y = 0; y < _inputSize; y++) {
    for (int x = 0; x < _inputSize; x++) {
      final pixel = resized.getPixel(x, y);
      out[idx++] = pixel.r.toInt();
      out[idx++] = pixel.g.toInt();
      out[idx++] = pixel.b.toInt();
    }
  }
  return out;
}

// ─── Inference (runs in isolate) ─────────────────────────────────────────────

AnalysisResult _runInference(Uint8List modelBytes, Uint8List rgbPixels,
    {bool isWarmUp = false}) {
  final interpreter = Interpreter.fromBuffer(modelBytes,
      options: InterpreterOptions()..threads = 4);

  // Set 4D shape before allocating — without this the PAD layer fails (4 != 1)
  interpreter.resizeInputTensor(0, [1, _inputSize, _inputSize, 3]);
  interpreter.allocateTensors();

  // Write input via the data setter (writes via setRange on native memory).
  // tensor.data getter is .asUnmodifiableView() — can't be written to directly.
  // runForMultipleInputs(Float32List) auto-reshapes the tensor to 1D — breaks PAD.
  if (!isWarmUp) {
    final inputFloat32 = Float32List(_inputSize * _inputSize * 3);
    for (int i = 0; i < rgbPixels.length; i++) {
      inputFloat32[i] = rgbPixels[i] / 255.0;
    }
    interpreter.getInputTensors().first.data = inputFloat32.buffer.asUint8List();
  }

  // Invoke directly — shape stays [1,1024,1024,3] as set by resizeInputTensor
  interpreter.invoke();

  if (isWarmUp) {
    interpreter.close();
    return const AnalysisResult(detections: []);
  }

  // Discover which output is detection vs proto by shape
  final outputTensors = interpreter.getOutputTensors();
  int detIdx = -1, protoIdx = -1;
  bool protoIsNHWC = true;

  for (int i = 0; i < outputTensors.length; i++) {
    final shape = outputTensors[i].shape;
    if (shape.length == 3 && shape[1] == _numFeatures) {
      detIdx = i;
    } else if (shape.length == 4 && shape[3] == _numMaskCoeff) {
      protoIdx = i;
      protoIsNHWC = true;
    } else if (shape.length == 4 && shape[1] == _numMaskCoeff) {
      protoIdx = i;
      protoIsNHWC = false;
    }
  }

  if (detIdx < 0 || protoIdx < 0) {
    debugPrint(
        '⚠️ Outputs não encontrados. Shapes: ${outputTensors.map((t) => t.shape).toList()}');
    interpreter.close();
    return const AnalysisResult(detections: []);
  }

  // tensor.data returns an unmodifiable view of native memory — copy first,
  // then reinterpret as Float32List before closing interpreter.
  final detFlat =
      Float32List.view(Uint8List.fromList(outputTensors[detIdx].data).buffer);
  final rawProto =
      Float32List.view(Uint8List.fromList(outputTensors[protoIdx].data).buffer);
  interpreter.close();

  final protoFlat =
      protoIsNHWC ? rawProto : _transposeProtoNCHWtoNHWC(rawProto);

  final numAnchors = detFlat.length ~/ _numFeatures;
  var detections = _decodeDetections(detFlat, numAnchors);
  detections = _applyNMS(detections);
  detections = _decodeMasks(detections, protoFlat);
  debugPrint('✅ ${detections.length} detecções');
  return AnalysisResult(detections: detections);
}

// ─── Decode detections ────────────────────────────────────────────────────────

List<Detection> _decodeDetections(Float32List flat, int numAnchors) {
  final detections = <Detection>[];

  for (int a = 0; a < numAnchors; a++) {
    final cx = flat[0 * numAnchors + a];
    final cy = flat[1 * numAnchors + a];
    final w = flat[2 * numAnchors + a];
    final h = flat[3 * numAnchors + a];

    double bestScore = double.negativeInfinity;
    int bestClass = 0;
    for (int c = 0; c < _numClasses; c++) {
      final s = flat[(4 + c) * numAnchors + a];
      if (s > bestScore) {
        bestScore = s;
        bestClass = c;
      }
    }

    final confidence = _sigmoid(bestScore);
    if (confidence < _confidenceThreshold) continue;

    final label = FungalClass.fromIndex(bestClass);
    if (label == null) continue;

    // Model outputs already-normalized (0–1) coordinates
    final left = (cx - w / 2).clamp(0.0, 1.0);
    final top = (cy - h / 2).clamp(0.0, 1.0);
    final right = (cx + w / 2).clamp(0.0, 1.0);
    final bottom = (cy + h / 2).clamp(0.0, 1.0);

    if (right <= left || bottom <= top) continue;

    final coeffs = List<double>.generate(
      _numMaskCoeff,
      (k) => flat[(4 + _numClasses + k) * numAnchors + a].toDouble(),
    );

    detections.add(Detection(
      classLabel: label,
      confidence: confidence,
      boundingBox: Rect.fromLTRB(left, top, right, bottom),
      maskCoefficients: coeffs,
    ));
  }
  return detections;
}

// ─── NMS per class ────────────────────────────────────────────────────────────

List<Detection> _applyNMS(List<Detection> detections) {
  final result = <Detection>[];
  for (final label in FungalClass.values) {
    final sorted = detections
        .where((d) => d.classLabel == label)
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    if (sorted.isEmpty) continue;
    result.add(sorted.first); // keep only the highest-confidence detection per class
  }
  return result;
}

// ─── Mask decoding ────────────────────────────────────────────────────────────

List<Detection> _decodeMasks(List<Detection> detections, Float32List protoFlat) {
  return detections.map((det) {
    final x0 = math.max(0, (det.boundingBox.left * _maskSize).toInt());
    final y0 = math.max(0, (det.boundingBox.top * _maskSize).toInt());
    final x1 = math.min(_maskSize, (det.boundingBox.right * _maskSize).toInt());
    final y1 = math.min(_maskSize, (det.boundingBox.bottom * _maskSize).toInt());

    final mask = List.generate(_maskSize, (_) => List.filled(_maskSize, false));

    for (int r = y0; r < y1; r++) {
      for (int c = x0; c < x1; c++) {
        double logit = 0.0;
        // proto [1, 256, 256, 32] NHWC: index = r*256*32 + c*32 + k
        final base = r * _maskSize * _numMaskCoeff + c * _numMaskCoeff;
        for (int k = 0; k < _numMaskCoeff; k++) {
          logit += det.maskCoefficients[k] * protoFlat[base + k];
        }
        mask[r][c] = _sigmoid(logit) > 0.5;
      }
    }

    return det.copyWith(decodedMask: mask);
  }).toList();
}

// ─── Transpose proto NCHW → NHWC ─────────────────────────────────────────────

Float32List _transposeProtoNCHWtoNHWC(Float32List nchw) {
  const h = _maskSize, w = _maskSize, c = _numMaskCoeff;
  final nhwc = Float32List(h * w * c);
  for (int k = 0; k < c; k++) {
    for (int r = 0; r < h; r++) {
      for (int col = 0; col < w; col++) {
        nhwc[r * w * c + col * c + k] = nchw[k * h * w + r * w + col];
      }
    }
  }
  return nhwc;
}

// ─── Math helpers ─────────────────────────────────────────────────────────────

double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));
