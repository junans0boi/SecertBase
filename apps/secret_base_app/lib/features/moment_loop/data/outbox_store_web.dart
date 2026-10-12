import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'outbox_store.dart';

OutboxStore createStore() => IndexedDbOutboxStore();

class IndexedDbOutboxStore implements OutboxStore {
  Future<Database>? _database;
  Future<Database> _open() => _database ??= idbFactoryBrowser.open(
    'secretbase_moment_outbox',
    version: 1,
    onUpgradeNeeded: (event) {
      event.database.createObjectStore('drafts');
      event.database.createObjectStore('media');
    },
  );

  @override
  Future<List<Map<String, dynamic>>> load() async {
    final db = await _open();
    final tx = db.transaction('drafts', idbModeReadOnly);
    final values = await tx.objectStore('drafts').getAll();
    await tx.completed;
    return values.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  @override
  Future<void> save(String id, Map<String, dynamic> record) async {
    final db = await _open();
    final tx = db.transaction('drafts', idbModeReadWrite);
    await tx.objectStore('drafts').put(record, id);
    await tx.completed;
  }

  @override
  Future<void> writeMedia(String key, Uint8List bytes) async {
    final db = await _open();
    final tx = db.transaction('media', idbModeReadWrite);
    await tx.objectStore('media').put(Uint8List.fromList(bytes), key);
    await tx.completed;
  }

  @override
  Future<Uint8List> readMedia(String key) async {
    final db = await _open();
    final tx = db.transaction('media', idbModeReadOnly);
    final value = await tx.objectStore('media').getObject(key);
    await tx.completed;
    if (value is! List) throw StateError('Missing persisted outbox media');
    return Uint8List.fromList(value.cast<int>());
  }
}
