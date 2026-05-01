import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/history_entry.dart';

class HistoryStore extends ChangeNotifier {
  List<HistoryEntry> _entries = [];
  late Directory _imagesDir;
  late File _entriesFile;
  bool _initialized = false;

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> initialize() async {
    if (_initialized) return;
    final docs = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${docs.path}/History');
    _imagesDir = Directory('${historyDir.path}/Images');
    _entriesFile = File('${historyDir.path}/entries.json');
    await _imagesDir.create(recursive: true);
    await _load();
    _initialized = true;
    notifyListeners();
  }

  Future<void> add(HistoryEntry entry, Uint8List jpegBytes) async {
    await _ensureInit();
    await _imageFile(entry.id).writeAsBytes(jpegBytes);
    _entries.insert(0, entry);
    await _save();
    notifyListeners();
  }

  Future<void> deleteAt(int index) async {
    await _ensureInit();
    final entry = _entries[index];
    final f = _imageFile(entry.id);
    if (await f.exists()) await f.delete();
    _entries.removeAt(index);
    await _save();
    notifyListeners();
  }

  Future<void> rename(String id, String newName) async {
    await _ensureInit();
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _entries[idx] = _entries[idx].renamed(newName);
    await _save();
    notifyListeners();
  }

  Future<void> deleteAll() async {
    await _ensureInit();
    for (final entry in _entries) {
      final f = _imageFile(entry.id);
      if (await f.exists()) await f.delete();
    }
    _entries.clear();
    await _save();
    notifyListeners();
  }

  Uint8List? thumbnail(String id) {
    final f = _imageFile(id);
    if (f.existsSync()) return f.readAsBytesSync();
    return null;
  }

  Future<File?> generateCSV() async {
    await _ensureInit();
    final buf = StringBuffer();
    buf.writeln('Nome,Data,Confiança Fungo (%),Confiança Escala (%),Escala (cm),Área (cm²),Área (mm²)');
    for (final e in _entries) {
      final fungalConf = e.fungalConfidence != null ? (e.fungalConfidence! * 100).toStringAsFixed(1) : '';
      final scaleConf = e.scaleConfidence != null ? (e.scaleConfidence! * 100).toStringAsFixed(1) : '';
      buf.writeln([
        e.imageName,
        e.date.toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        fungalConf,
        scaleConf,
        e.scaleLengthCm.toStringAsFixed(2),
        e.fungalAreaCm2.toStringAsFixed(4),
        e.fungalAreaMm2.toStringAsFixed(2),
      ].join(','));
    }
    final tmp = await getTemporaryDirectory();
    final csv = File('${tmp.path}/FungalAnalyzer_Historico.csv');
    await csv.writeAsString(buf.toString());
    return csv;
  }

  File _imageFile(String id) => File('${_imagesDir.path}/$id.jpg');

  Future<void> _ensureInit() async {
    if (!_initialized) await initialize();
  }

  Future<void> _save() async {
    await _entriesFile.writeAsString(HistoryEntry.listToJson(_entries));
  }

  Future<void> _load() async {
    if (!await _entriesFile.exists()) return;
    try {
      final json = await _entriesFile.readAsString();
      _entries = HistoryEntry.listFromJson(json);
    } catch (_) {
      _entries = [];
    }
  }
}
