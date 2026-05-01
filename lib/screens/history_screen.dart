import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_entry.dart';
import '../services/history_store.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        centerTitle: true,
        actions: [
          Consumer<HistoryStore>(
            builder: (_, store, __) => store.entries.isEmpty
                ? const SizedBox.shrink()
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (v) {
                      if (v == 'export') _exportCSV(store);
                      if (v == 'delete') _confirmDeleteAll(store);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: Icon(Icons.table_chart_outlined),
                          title: Text('Exportar CSV'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Apagar Tudo', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      body: Consumer<HistoryStore>(
        builder: (_, store, __) {
          if (store.entries.isEmpty) return _emptyState();
          return _entryList(store);
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('Nenhuma análise salva',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            'Salve análises na tela de resultado\npara vê-las aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _entryList(HistoryStore store) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: store.entries.length + 1,
      itemBuilder: (_, i) {
        if (i == store.entries.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Text(
                '${store.entries.length} análise(s) salva(s)',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          );
        }
        final entry = store.entries[i];
        return _EntryCard(
          entry: entry,
          thumbnail: store.thumbnail(entry.id),
          dateFormat: _dateFormat,
          onDelete: () => store.deleteAt(i),
          onRename: (name) => store.rename(entry.id, name),
        );
      },
    );
  }

  Future<void> _exportCSV(HistoryStore store) async {
    final file = await store.generateCSV();
    if (file == null || !mounted) return;
    await Share.shareXFiles([XFile(file.path)], text: 'FungalAnalyzer - Histórico');
  }

  Future<void> _confirmDeleteAll(HistoryStore store) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar todo o histórico?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) store.deleteAll();
  }
}

class _EntryCard extends StatelessWidget {
  final HistoryEntry entry;
  final Uint8List? thumbnail;
  final DateFormat dateFormat;
  final VoidCallback onDelete;
  final void Function(String) onRename;

  const _EntryCard({
    required this.entry,
    required this.thumbnail,
    required this.dateFormat,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Dismissible(
        key: Key(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Apagar análise?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Apagar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          return confirm == true;
        },
        onDismissed: (_) => onDelete(),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _thumbnail(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.imageName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(dateFormat.format(entry.date),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.fungalAreaCm2.toStringAsFixed(4),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text('cm²', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    if (thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(thumbnail!, width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.photo_outlined, color: Colors.grey[400]),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renomear'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: entry.imageName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nome'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) onRename(name);
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
