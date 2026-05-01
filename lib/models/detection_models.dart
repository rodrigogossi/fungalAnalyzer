import 'dart:ui';

enum FungalClass {
  scale(0),
  fungus(1);

  const FungalClass(this.classIndex);
  final int classIndex;

  String get displayName {
    switch (this) {
      case FungalClass.fungus:
        return 'Fungo';
      case FungalClass.scale:
        return 'Escala';
    }
  }

  Color get overlayColor {
    switch (this) {
      case FungalClass.fungus:
        return const Color.fromRGBO(255, 115, 0, 0.70);
      case FungalClass.scale:
        return const Color.fromRGBO(255, 199, 38, 0.75);
    }
  }

  Color get strokeColor {
    switch (this) {
      case FungalClass.fungus:
        return const Color.fromRGBO(255, 89, 0, 1.0);
      case FungalClass.scale:
        return const Color.fromRGBO(255, 173, 0, 1.0);
    }
  }

  static FungalClass? fromIndex(int index) {
    return FungalClass.values.where((c) => c.classIndex == index).firstOrNull;
  }
}

class Detection {
  final FungalClass classLabel;
  final double confidence;

  /// Bounding box normalizado 0-1, origem top-left
  final Rect boundingBox;

  /// 32 coeficientes de máscara
  final List<double> maskCoefficients;

  /// Máscara 256×256 decodificada (true = pixel pertence ao objeto)
  final List<List<bool>>? decodedMask;

  const Detection({
    required this.classLabel,
    required this.confidence,
    required this.boundingBox,
    required this.maskCoefficients,
    this.decodedMask,
  });

  Detection copyWith({List<List<bool>>? decodedMask}) {
    return Detection(
      classLabel: classLabel,
      confidence: confidence,
      boundingBox: boundingBox,
      maskCoefficients: maskCoefficients,
      decodedMask: decodedMask ?? this.decodedMask,
    );
  }
}

class AnalysisResult {
  final List<Detection> detections;

  const AnalysisResult({required this.detections});

  Detection? get fungalDetection => detections
      .where((d) => d.classLabel == FungalClass.fungus)
      .fold<Detection?>(null, (best, d) => best == null || d.confidence > best.confidence ? d : best);

  Detection? get scaleDetection => detections
      .where((d) => d.classLabel == FungalClass.scale)
      .fold<Detection?>(null, (best, d) => best == null || d.confidence > best.confidence ? d : best);

  /// Número de pixels na máscara do fungo (espaço 256×256)
  int get fungalMaskPixelCount {
    final mask = fungalDetection?.decodedMask;
    if (mask == null) return 0;
    return mask.fold(0, (sum, row) => sum + row.where((v) => v).length);
  }

  /// Maior dimensão do bounding box da escala, em pixels do espaço 256×256
  double get scalePixelLength {
    final scale = scaleDetection;
    if (scale == null) return 0;
    const maskSize = 256.0;
    final wPx = scale.boundingBox.width * maskSize;
    final hPx = scale.boundingBox.height * maskSize;
    return wPx > hPx ? wPx : hPx;
  }

  /// Calcula a área do fungo em cm²
  double? calculateFungalArea(double scaleLengthCm) {
    if (scaleLengthCm <= 0 || scalePixelLength <= 0 || fungalMaskPixelCount <= 0) {
      return null;
    }
    final pixelsPerCm = scalePixelLength / scaleLengthCm;
    return fungalMaskPixelCount / (pixelsPerCm * pixelsPerCm);
  }
}
