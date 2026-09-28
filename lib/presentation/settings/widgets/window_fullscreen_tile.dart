import 'package:flutter/material.dart';
import 'package:fluxtube/core/window_fullscreen.dart';
import 'package:fluxtube/generated/l10n.dart';

/// Switch that hides the desktop title bar and keeps the window fullscreen.
class WindowFullscreenTile extends StatefulWidget {
  const WindowFullscreenTile({super.key});

  @override
  State<WindowFullscreenTile> createState() => _WindowFullscreenTileState();
}

class _WindowFullscreenTileState extends State<WindowFullscreenTile> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WindowFullscreen.loadAndApply().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    await WindowFullscreen.setEnabled(value);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!WindowFullscreen.isSupported) return const SizedBox.shrink();
    final locals = S.of(context);
    return ListTile(
      title: Text(locals.windowFullscreen,
          style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(locals.windowFullscreenDescription),
      leading: const Icon(Icons.fullscreen),
      trailing: Switch(
        value: WindowFullscreen.enabled,
        onChanged: _busy ? null : _toggle,
      ),
    );
  }
}
