import 'dart:convert';

class HistoryEntry {
  final String id;
  final DateTime date;
  String imageName;
  final double? fungalConfidence;
  final double? scaleConfidence;
  final int fungalMaskPixelCount;
  final double scalePixelLength;
  final double scaleLengthCm;
  final double fungalAreaCm2;

  HistoryEntry({
    String? id,
    DateTime? date,
    required this.imageName,
    this.fungalConfidence,
    this.scaleConfidence,
    required this.fungalMaskPixelCount,
    required this.scalePixelLength,
    required this.scaleLengthCm,
    required this.fungalAreaCm2,
  })  : id = id ?? _generateId(),
        date = date ?? DateTime.now();

  double get fungalAreaMm2 => fungalAreaCm2 * 100;

  static String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString() +
        '_' +
        (DateTime.now().millisecond).toString();
  }

  HistoryEntry renamed(String newName) {
    return HistoryEntry(
      id: id,
      date: date,
      imageName: newName,
      fungalConfidence: fungalConfidence,
      scaleConfidence: scaleConfidence,
      fungalMaskPixelCount: fungalMaskPixelCount,
      scalePixelLength: scalePixelLength,
      scaleLengthCm: scaleLengthCm,
      fungalAreaCm2: fungalAreaCm2,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'imageName': imageName,
        'fungalConfidence': fungalConfidence,
        'scaleConfidence': scaleConfidence,
        'fungalMaskPixelCount': fungalMaskPixelCount,
        'scalePixelLength': scalePixelLength,
        'scaleLengthCm': scaleLengthCm,
        'fungalAreaCm2': fungalAreaCm2,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        imageName: json['imageName'] as String,
        fungalConfidence: (json['fungalConfidence'] as num?)?.toDouble(),
        scaleConfidence: (json['scaleConfidence'] as num?)?.toDouble(),
        fungalMaskPixelCount: json['fungalMaskPixelCount'] as int,
        scalePixelLength: (json['scalePixelLength'] as num).toDouble(),
        scaleLengthCm: (json['scaleLengthCm'] as num).toDouble(),
        fungalAreaCm2: (json['fungalAreaCm2'] as num).toDouble(),
      );

  static List<HistoryEntry> listFromJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<HistoryEntry> entries) {
    return jsonEncode(entries.map((e) => e.toJson()).toList());
  }
}
