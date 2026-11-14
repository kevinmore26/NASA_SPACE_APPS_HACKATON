import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Bounded on-demand HTTP tile cache, no prefetch or bulk download.
class CachedTileClient extends http.BaseClient {
  final Directory directory;
  final http.Client _network;
  final int maxBytes;
  bool offline = false;
  final Map<String, Future<List<int>>> _pending = {};
  final List<Completer<void>> _queue = [];
  int _active = 0;
  Future<void> _maintenance = Future.value();
  CachedTileClient(
    this.directory, {
    http.Client? network,
    this.maxBytes = 128 * 1024 * 1024,
  }) : _network = network ?? http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final key = sha256.convert(utf8.encode(request.url.toString())).toString();
    final future = _pending.putIfAbsent(key, () => _load(key, request));
    try {
      return http.StreamedResponse(
        Stream.value(await future),
        200,
        request: request,
      );
    } finally {
      _pending.remove(key);
    }
  }

  Future<List<int>> _load(String key, http.BaseRequest request) async {
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, key));
    if (await file.exists()) {
      final stat = await file.stat();
      // Offline may use stale tiles, explicitly labelled by the app.
      if (offline || DateTime.now().difference(stat.modified).inDays < 7)
        return file.readAsBytes();
    }
    if (offline) throw const SocketException('Esta zona no está descargada.');
    if (_active >= 6) {
      final waiter = Completer<void>();
      _queue.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      final response = await _network
          .get(
            request.url,
            headers: {
              ...request.headers,
              'User-Agent': 'NASAFieldShift/0.1 (Windows; agricultural viewer)',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty)
        throw http.ClientException(
          'Tesela no disponible (${response.statusCode})',
        );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      _maintenance = _maintenance
          .then((_) => _trim())
          .catchError((Object _) {});
      return response.bodyBytes;
    } catch (_) {
      if (await file.exists()) return file.readAsBytes();
      rethrow;
    } finally {
      _active--;
      if (_queue.isNotEmpty) _queue.removeAt(0).complete();
    }
  }

  Future<void> _trim() async {
    final entries = <FileSystemEntity, FileStat>{};
    await for (final f in directory.list()) {
      if (f is File) entries[f] = await f.stat();
    }
    var size = entries.values.fold<int>(0, (s, v) => s + v.size);
    final ordered = entries.keys.toList()
      ..sort((a, b) => entries[a]!.modified.compareTo(entries[b]!.modified));
    for (final f in ordered) {
      if (size <= maxBytes) break;
      size -= entries[f]!.size;
      try {
        await f.delete();
      } on FileSystemException {}
    }
  }

  Future<void> flush() => _maintenance;
  @override
  void close() {
    _network.close();
    super.close();
  }
}
