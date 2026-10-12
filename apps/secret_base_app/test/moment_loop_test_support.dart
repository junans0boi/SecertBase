import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:secret_base_app/core/http/api_client.dart';
import 'package:secret_base_app/features/moment_loop/application/upload_outbox.dart';
import 'package:secret_base_app/features/moment_loop/data/outbox_store.dart';

UploadOutbox testOutbox(http.Client client) => UploadOutbox(
  store: MemoryOutboxStore(), currentUserId: () => 7,
  apiClient: ApiClient(baseUrl: 'https://secretbase.example', tokenProvider: () => 'test-token', client: client),
);

// Durable file-system boundary simulated independently of the queue lifetime.
class MemoryOutboxStore implements OutboxStore {
  final Map<String, Map<String, dynamic>> records = {};
  final Map<String, Uint8List> files = {};
  @override
  Future<List<Map<String, dynamic>>> load() async => records.values
      .map((r) => Map<String, dynamic>.from(jsonDecode(jsonEncode(r))))
      .toList();
  @override
  Future<void> save(String id, Map<String, dynamic> record) async {
    records[id] = Map<String, dynamic>.from(jsonDecode(jsonEncode(record)));
  }
  @override
  Future<void> removeDraft(String id) async {
    records.remove(id);
  }
  @override
  Future<void> writeMedia(String key, Uint8List bytes) async {
    files[key] = Uint8List.fromList(bytes);
  }
  @override
  Future<Uint8List> readMedia(String key) async => Uint8List.fromList(files[key]!);
  @override
  Future<void> removeMedia(String key) async {
    files.remove(key);
  }
}
