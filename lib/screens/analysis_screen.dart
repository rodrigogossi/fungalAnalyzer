import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detection_models.dart';
import '../models/history_entry.dart';
import '../services/fungal_detector.dart';
import '../services/history_store.dart';

class AnalysisScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final FungalDetector detector;
  final ImageSource imageSource;

  const AnalysisScreen({
    super.key,
    required this.imageBytes,
    required this.detector,
    required this.imageSource,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  AnalysisResult? _result;

  /// Pre-rendered overlay image (base image + mask + bboxes), like Swift's UIGraphicsImageRenderer
  Uint8List? _overlayBytes;

  bool _isAnalyzing = true;
  String? _errorMessage;

  final _scaleLengthController = TextEditingController();
  final _imageNameController = TextEditingController();
  double? _calculatedArea;
  bool _savedToHistory = false;

  @override
  void initState() {
    super.initState();
    _scaleLengthController.addListener(() => setState(() {}));
    _loadLastScale();
    _runAnalysis();
  }

  @override
  void dispose() {
    _scaleLengthController.dispose();
    _imageNameController.dispose();
    super.dispose();
  }

  // ─── Analysis ────────────────────────────────────────────────────────────────

  Future<void> _runAnalysis() async {
    final store = context.read<HistoryStore>();
    _imageNameController.text = 'Imagem ${store.entries.length + 1}';

    try {
      final result = await widget.detector.detect(widget.imageBytes);

      // Render overlay (base image + masks + bboxes) as bitmap, like Swift renderOverlay()
      final overlayBytes = await _renderOverlay(widget.imageBytes, result.detections);

      if (mounted) {
        setState(() {
          _result = result;
          _overlayBytes = overlayBytes;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  /// Renders base image + segmentation masks + bounding boxes into a single bitmap.
  /// Equivalent to Swift's renderOverlay(on:result:).
  Future<Uint8List?> _renderOverlay(
      Uint8List imageBytes, List<Detection> detections) async {
    // Decode original image
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final baseImage = frame.image;
    final w = baseImage.width.toDouble();
    final h = baseImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw original image
    canvas.drawImage(baseImage, Offset.zero, Paint());

    for (final det in detections) {
      // Draw segmentation mask if available
      if (det.decodedMask != null) {
        final maskImg =
            await _buildMaskImage(det.decodedMask!, det.classLabel.overlayColor);
        if (maskImg != null) {
          // Scale 256×256 mask to full image size
          canvas.drawImageRect(
            maskImg,
            const Rect.fromLTWH(0, 0, 256, 256),
            Rect.fromLTWH(0, 0, w, h),
            Paint()..blendMode = ui.BlendMode.srcOver,
          );
        }
      }

      // Bounding box
      final bbox = Rect.fromLTWH(
        det.boundingBox.left * w,
        det.boundingBox.top * h,
        det.boundingBox.width * w,
        det.boundingBox.height * h,
      );
      final strokeW = (w / 300).clamp(2.0, 6.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bbox, const Radius.circular(4)),
        Paint()
          ..color = det.classLabel.strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW,
      );

      // Label background + text
      final label =
          '${det.classLabel.displayName}  ${(det.confidence * 100).toStringAsFixed(0)}%';
      final fontSize = (w / 45).clamp(12.0, 28.0);
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fontSize))
        ..pushStyle(ui.TextStyle(
            color: const Color(0xFFFFFFFF),
            fontSize: fontSize,
            fontWeight: FontWeight.w600))
        ..addText(label);
      final para = pb.build()
        ..layout(ui.ParagraphConstraints(width: w));

      final labelY = (bbox.top - para.height - 10).clamp(0.0, h - para.height - 10);
      final labelRect = Rect.fromLTWH(
          bbox.left + 4, labelY, para.longestLine + 10, para.height + 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        Paint()..color = const Color(0x99000000),
      );
      canvas.drawParagraph(para, Offset(labelRect.left + 5, labelRect.top + 4));
    }

    final picture = recorder.endRecording();
    final renderedImage =
        await picture.toImage(baseImage.width, baseImage.height);
    final byteData =
        await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Creates a 256×256 RGBA ui.Image from a boolean mask and a color.
  /// Equivalent to Swift's buildMaskImage(_:color:size:).
  Future<ui.Image?> _buildMaskImage(List<List<bool>> mask, Color color) async {
    const size = 256;
    final pixels = Uint8List(size * size * 4);
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    final a = (color.a * 255.0).round().clamp(0, 255);

    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        if (mask[row][col]) {
          final idx = (row * size + col) * 4;
          pixels[idx] = r;
          pixels[idx + 1] = g;
          pixels[idx + 2] = b;
          pixels[idx + 3] = a;
        }
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        pixels, size, size, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  // ─── Area calculation ─────────────────────────────────────────────────────────

  Future<void> _loadLastScale() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('lastScaleCm');
    if (last != null && mounted) {
      _scaleLengthController.text = last;
    }
  }

  Future<void> _saveLastScale(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastScaleCm', value);
  }

  void _calculateArea() {
    final result = _result;
    if (result == null) return;
    final normalized = _scaleLengthController.text.replaceAll(',', '.');
    final cm = double.tryParse(normalized);
    if (cm == null || cm <= 0) return;

    _saveLastScale(normalized);

    final area = result.calculateFungalArea(cm);
    setState(() => _calculatedArea = area);

    if (area != null) _saveToHistory(result, area, cm);
  }

  void _saveToHistory(AnalysisResult result, double area, double scaleCm) {
    if (_savedToHistory) return;
    _savedToHistory = true;

    final name = _imageNameController.text.trim().isEmpty
        ? 'Imagem ${context.read<HistoryStore>().entries.length + 1}'
        : _imageNameController.text.trim();

    final entry = HistoryEntry(
      imageName: name,
      fungalConfidence: result.fungalDetection?.confidence,
      scaleConfidence: result.scaleDetection?.confidence,
      fungalMaskPixelCount: result.fungalMaskPixelCount,
      scalePixelLength: result.scalePixelLength,
      scaleLengthCm: scaleCm,
      fungalAreaCm2: area,
    );
    context.read<HistoryStore>().add(entry, _overlayBytes ?? widget.imageBytes);
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Análise'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            _imageSection(),
            const SizedBox(height: 12),
            if (_isAnalyzing)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 12),
                    Text('Analisando imagem…'),
                  ],
                ),
              )
            else if (_errorMessage != null)
              _errorView(_errorMessage!)
            else if (_result != null) ...[
              _detectionsSection(_result!),
              const SizedBox(height: 12),
              if (_result!.scaleDetection != null && _result!.fungalDetection != null)
                _calibrationSection()
              else
                _missingDetectionWarning(_result!),
              if (_calculatedArea != null) ...[
                const SizedBox(height: 12),
                _areaResultSection(_calculatedArea!),
                const SizedBox(height: 8),
                _savedStatus(),
                const SizedBox(height: 12),
                _nextCaptureButton(),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _imageSection() {
    final displayBytes = _overlayBytes ?? widget.imageBytes;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Image.memory(displayBytes, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _errorView(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Widget _detectionsSection(AnalysisResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.search, size: 18),
              SizedBox(width: 6),
              Text('Detecções',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ]),
            const SizedBox(height: 10),
            if (result.detections.isEmpty)
              Text('Nenhuma detecção encontrada.',
                  style: TextStyle(color: Colors.grey[500]))
            else
              ...result.detections.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: d.classLabel.overlayColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(d.classLabel.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(
                          '${(d.confidence * 100).toStringAsFixed(1)}%',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _missingDetectionWarning(AnalysisResult result) {
    final String missing;
    if (result.fungalDetection == null && result.scaleDetection == null) {
      missing = 'fungo e escala';
    } else if (result.fungalDetection == null) {
      missing = 'fungo';
    } else {
      missing = 'escala';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Não foi detectado: $missing. Tente tirar a foto com melhor iluminação.',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calibrationSection() {
    final canCalculate = _scaleLengthController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.tune, size: 18),
              SizedBox(width: 6),
              Text('Configuração',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Text('Nome', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _imageNameController,
                  decoration: const InputDecoration(
                    hintText: 'ex: Placa A1',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Text('Escala', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _scaleLengthController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'ex: 1.0',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('cm', style: TextStyle(fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: canCalculate ? _calculateArea : null,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Calcular Área',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _areaResultSection(double area) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.pie_chart, color: Colors.orange, size: 18),
              SizedBox(width: 6),
              Text('Área do Fungo',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text(
              '${area.toStringAsFixed(4)} cm²',
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace'),
            ),
            Text(
              '(${(area * 100).toStringAsFixed(2)} mm²)',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedStatus() {
    final store = context.watch<HistoryStore>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 6),
          Text('Salvo no histórico', style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text('#${store.entries.length}',
              style: const TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _nextCaptureButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(context, widget.imageSource),
          icon: Icon(widget.imageSource == ImageSource.camera
              ? Icons.camera_alt
              : Icons.photo_library_outlined),
          label: const Text('Próxima Captura',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

}
