import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'ubuntu_touch.dart';

/// Lomiri writes the system theme here. The Click profile already allows
/// reading this file. SuruDark is the dark theme; Ambiance and SuruGradient
/// are light.
class LomiriSystemTheme {
  static const String fileName = 'theme.ini';

  static String? lastName;
  static bool _loggedName = false;
  static String? _lastError;

  static Future<Brightness?> read() async {
    if (!UbuntuTouch.enabled) return null;
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      print('gastube: lomiri theme skipped, HOME is unset');
      return null;
    }
    final file = File(
      p.join(home, '.config', 'lomiri-ui-toolkit', fileName),
    );
    try {
      final text = await file.readAsString();
      final name = _themeName(text);
      if (!_loggedName || name != lastName) {
        _loggedName = true;
        print('gastube: lomiri theme file=${file.path} name=$name');
      }
      lastName = name;
      if (name == null || name.isEmpty) return null;
      if (name.toLowerCase().contains('dark')) return Brightness.dark;
      return Brightness.light;
    } catch (error) {
      final message = error.toString();
      if (message != _lastError) {
        _lastError = message;
        print('gastube: lomiri theme read failed: $error');
      }
      return null;
    }
  }

  static String? _themeName(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('[')) {
        continue;
      }
      final eq = trimmed.indexOf('=');
      if (eq < 0) continue;
      if (trimmed.substring(0, eq).trim() != 'theme') continue;
      var value = trimmed.substring(eq + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      return value;
    }
    return null;
  }
}
