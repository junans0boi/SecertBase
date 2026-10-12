import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'outbox_store.dart';

OutboxStore createStore() => DocumentOutboxStore();

class DocumentOutboxStore implements OutboxStore {
  final Future<Directory> Function() documentsDirectory;
  Future<Directory>? _directory;

  DocumentOutboxStore({Future<Directory> Function()? documentsDirectory})
    : documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  Future<Directory> _root() => _directory ??= () async {
    final documents = await documentsDirectory();
    return Directory(
      '${documents.path}/moment_loop_outbox',
    ).create(recursive: true);
  }();

  void _validateKey(String key) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(key)) {
      throw ArgumentError('Invalid outbox key');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> load() async {
    final root = await _root();
    final records = <Map<String, dynamic>>[];
    await for (final entity in root.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        // Do not silently replace unreadable user drafts with an empty queue.
        records.add(
          Map<String, dynamic>.from(
            jsonDecode(await entity.readAsString()) as Map,
          ),
        );
      }
    }
    return records;
  }

  @override
  Future<void> save(String id, Map<String, dynamic> record) async {
    _validateKey(id);
    final root = await _root();
    final pending = File('${root.path}/$id.pending');
    await pending.writeAsString(jsonEncode(record), flush: true);
    await pending.rename('${root.path}/$id.json');
  }

  @override
  Future<void> writeMedia(String key, Uint8List bytes) async {
    _validateKey(key);
    final root = await _root();
    await File('${root.path}/$key.media').writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List> readMedia(String key) async {
    _validateKey(key);
    final root = await _root();
    return File('${root.path}/$key.media').readAsBytes();
  }
}
