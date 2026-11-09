import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One JSON file written atomically: encode → `name.tmp` (flushed) →
/// rename over `name`. A crash mid-write leaves the old
/// main file intact and a `.tmp` that the next [read] deletes.
///
/// Single writer with coalescing: a [write] while another is in flight only
/// replaces the pending map, so the newest state always wins and a burst of
/// saves costs at most two disk writes.
///
/// `dir` is null on web (no file system): reads return null and writes do
/// nothing, so the app still runs, just without a cache.
class AtomicJsonFile {
  AtomicJsonFile(this._dir, this.name, {this.onWritten});

  final Future<Directory>? _dir;
  final String name;

  /// Called with the encoded size of every disk write.
  final void Function(int bytes)? onWritten;

  Future<void>? _inFlight;
  Map<String, Object?>? _pending;
  Completer<void>? _pendingDone;

  @visibleForTesting
  int diskWrites = 0;

  Future<File?> _file(String fileName) async {
    final dir = _dir;
    if (dir == null) return null;
    return File('${(await dir).path}${Platform.pathSeparator}$fileName');
  }

  /// The raw text, or null when there is no file. Deletes a leftover `.tmp`
  /// first: the main file is the last complete write.
  Future<String?> readString() async {
    final tmp = await _file('$name.tmp');
    if (tmp == null) return null;
    if (await tmp.exists()) await tmp.delete();
    final main = await _file(name);
    if (main == null || !await main.exists()) return null;
    return main.readAsString();
  }

  /// The decoded object, or null when there is no file. Throws
  /// [FormatException] on bad JSON.
  Future<Map<String, Object?>?> read() async {
    final text = await readString();
    if (text == null) return null;
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('not a JSON object');
    }
    return decoded;
  }

  Future<void> write(Map<String, Object?> json) {
    if (_dir == null) return Future.value();
    if (_inFlight != null) {
      _pending = json;
      return (_pendingDone ??= Completer<void>()).future;
    }
    final done = Completer<void>();
    _inFlight = _drain(json, done);
    return done.future;
  }

  Future<void> _drain(Map<String, Object?> first, Completer<void> done) async {
    Map<String, Object?>? next = first;
    var waiter = done;
    while (next != null) {
      try {
        await _writeNow(next);
        waiter.complete();
      } catch (e, s) {
        waiter.completeError(e, s);
      }
      next = _pending;
      _pending = null;
      final pendingDone = _pendingDone;
      _pendingDone = null;
      if (pendingDone != null) waiter = pendingDone;
    }
    _inFlight = null;
  }

  Future<void> _writeNow(Map<String, Object?> json) async {
    final text = jsonEncode(json);
    final tmp = (await _file('$name.tmp'))!;
    await tmp.writeAsString(text, flush: true);
    await tmp.rename((await _file(name))!.path);
    diskWrites++;
    onWritten?.call(utf8.encode(text).length);
  }

  /// Drops a pending write, waits for the one in flight, then deletes both
  /// files.
  Future<void> delete() async {
    if (_dir == null) return;
    _pending = null;
    _pendingDone?.complete();
    _pendingDone = null;
    await _inFlight;
    for (final f in [await _file('$name.tmp'), await _file(name)]) {
      if (f != null && await f.exists()) await f.delete();
    }
  }
}
