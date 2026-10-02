import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  final machine = Abi.current().toString();
  final libc = _libcVersion();
  const flutterVersion = String.fromEnvironment(
    'GASTUBE_FLUTTER_VERSION',
    defaultValue: 'unknown',
  );
  const engineRevision = String.fromEnvironment(
    'GASTUBE_FLUTTER_ENGINE',
    defaultValue: 'unknown',
  );
  runApp(
    HelloApp(
      text: 'Flutter $flutterVersion\n'
          'engine $engineRevision\n'
          'machine $machine\n'
          'libc $libc\n'
          'dart ${Platform.version}',
    ),
  );
}

String _libcVersion() {
  final libc = DynamicLibrary.open('libc.so.6');
  final getVersion = libc.lookupFunction<Pointer<Char> Function(),
      Pointer<Char> Function()>('gnu_get_libc_version');
  final pointer = getVersion();
  final units = <int>[];
  var index = 0;
  while (true) {
    final unit = pointer.elementAt(index).value;
    if (unit == 0) {
      break;
    }
    units.add(unit);
    index += 1;
  }
  return String.fromCharCodes(units);
}

class HelloApp extends StatelessWidget {
  const HelloApp({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(text, textAlign: TextAlign.left),
        ),
      ),
    );
  }
}
