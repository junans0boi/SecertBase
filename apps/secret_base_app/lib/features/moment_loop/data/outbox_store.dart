import 'dart:typed_data';

import 'outbox_store_unsupported.dart'
    if (dart.library.io) 'outbox_store_io.dart'
    if (dart.library.js_interop) 'outbox_store_web.dart'
    as platform;

/// Durable boundary. A save completes only after the record is committed.
abstract class OutboxStore {
  Future<List<Map<String, dynamic>>> load();
  Future<void> save(String id, Map<String, dynamic> record);
  Future<void> removeDraft(String id);
  Future<void> writeMedia(String key, Uint8List bytes);
  Future<Uint8List> readMedia(String key);
  Future<void> removeMedia(String key);
}

OutboxStore createOutboxStore() => platform.createStore();
