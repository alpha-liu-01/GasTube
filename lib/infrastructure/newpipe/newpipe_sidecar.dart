import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class NewPipeSidecarException implements Exception {
  NewPipeSidecarException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Long-lived `java -jar` process that answers NewPipeChannel calls.
/// Android keeps the Kotlin method channel and does not start this.
class NewPipeSidecar {
  NewPipeSidecar._();

  static final NewPipeSidecar instance = NewPipeSidecar._();

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  final Map<int, Completer<String>> _pending = {};
  int _nextId = 1;
  Future<void>? _starting;

  bool get isRunning => _process != null;

  Future<void> ensureStarted() {
    final current = _starting;
    if (current != null) return current;
    if (_process != null) return Future.value();
    final starting = _start();
    _starting = starting;
    return starting.whenComplete(() {
      if (identical(_starting, starting)) _starting = null;
    });
  }

  Future<String> invoke(String method, Map<String, dynamic> args) async {
    await ensureStarted();
    final process = _process;
    if (process == null) {
      throw NewPipeSidecarException(
        'UNAVAILABLE',
        'NewPipe sidecar is not running',
      );
    }
    final id = _nextId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    process.stdin.writeln(jsonEncode({
      'id': id,
      'method': method,
      'args': args,
    }));
    try {
      return await completer.future.timeout(const Duration(seconds: 90));
    } on TimeoutException {
      _pending.remove(id);
      throw NewPipeSidecarException(
        'TIMEOUT',
        'NewPipe sidecar timed out on $method',
      );
    }
  }

  Future<void> shutdown() async {
    final process = _process;
    _process = null;
    _starting = null;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(
          NewPipeSidecarException('CLOSED', 'NewPipe sidecar stopped'),
        );
      }
    }
    _pending.clear();
    process?.kill();
  }

  String _resolveJava() {
    final override = Platform.environment['FLUXTUBE_JAVA'];
    if (override != null && override.isNotEmpty) return override;
    final bundledName = Platform.isWindows ? 'java.exe' : 'java';
    final bundled = p.join(
      p.dirname(Platform.resolvedExecutable),
      'jre',
      'bin',
      bundledName,
    );
    if (File(bundled).existsSync()) return bundled;
    return 'java';
  }

  Future<void> _start() async {
    final javaBin = _resolveJava();
    final jar = _findJar();
    if (jar == null) {
      throw NewPipeSidecarException(
        'JAR_MISSING',
        'NewPipe sidecar jar was not found. Build packaging/newpipe-spike '
            'or set FLUXTUBE_NEWPIPE_JAR.',
      );
    }
    debugPrint('[NewPipe] starting $javaBin -jar $jar');
    // The pipe is UTF-8 both ways. Windows defaults to the ANSI code page.
    // Cap the heap. The default max is a large fraction of RAM, so home-feed
    // searches expand java.exe until the collector stops growing it.
    final process = await Process.start(javaBin, [
      '-Xms32m',
      '-Xmx128m',
      '-Dfile.encoding=UTF-8',
      '-Dstdout.encoding=UTF-8',
      '-Dstderr.encoding=UTF-8',
      '-jar',
      jar,
    ]);
    process.stdin.encoding = utf8;
    _process = process;
    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine, onError: _onStreamError);
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      if (line.isNotEmpty) debugPrint('[NewPipe] $line');
    });
    unawaited(process.exitCode.then((code) {
      if (!identical(_process, process)) return;
      debugPrint('[NewPipe] sidecar exited ($code)');
      _process = null;
      _onStreamError(
        NewPipeSidecarException('EXITED', 'NewPipe sidecar exited ($code)'),
      );
    }));
  }

  void _onLine(String line) {
    if (line.isEmpty) return;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return;
      final id = decoded['id'];
      final requestId = id is int ? id : int.tryParse('$id');
      if (requestId == null) return;
      final pending = _pending.remove(requestId);
      if (pending == null || pending.isCompleted) return;
      if (decoded['ok'] == true) {
        final result = decoded['result'];
        pending.complete(result is String ? result : jsonEncode(result));
      } else {
        pending.completeError(
          NewPipeSidecarException(
            '${decoded['code'] ?? 'EXTRACTION_ERROR'}',
            '${decoded['message'] ?? 'NewPipe request failed'}',
          ),
        );
      }
    } catch (error) {
      debugPrint('[NewPipe] bad sidecar line: $error');
    }
  }

  void _onStreamError(Object error) {
    final pending = List<Completer<String>>.from(_pending.values);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error);
    }
  }

  String? _findJar() {
    final candidates = <String>[
      if (Platform.environment['FLUXTUBE_NEWPIPE_JAR'] != null)
        Platform.environment['FLUXTUBE_NEWPIPE_JAR']!,
      p.join(
        Directory.current.path,
        'packaging',
        'newpipe-spike',
        'build',
        'libs',
        'newpipe-spike.jar',
      ),
      p.join(p.dirname(Platform.resolvedExecutable), 'newpipe-spike.jar'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }
}
