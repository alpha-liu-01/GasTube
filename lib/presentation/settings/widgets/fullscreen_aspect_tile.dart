import 'package:flutter/material.dart';
import 'package:fluxtube/core/fullscreen_aspect.dart';
import 'package:fluxtube/generated/l10n.dart';

/// Switch for rotating the player fullscreen button with the video.
///
/// Stored in the settings table, like the new-upload switch, so each install
/// keeps its own value without a SettingsBloc field.
class FullscreenAspectTile extends StatefulWidget {
  const FullscreenAspectTile({super.key});

  @override
  State<FullscreenAspectTile> createState() => _FullscreenAspectTileState();
}

class _FullscreenAspectTileState extends State<FullscreenAspectTile> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    FullscreenAspect.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    await FullscreenAspect.setEnabled(value);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final locals = S.of(context);
    return ListTile(
      title: Text(locals.fullscreenAspectRotate,
          style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(locals.fullscreenAspectRotateDescription),
      leading: const Icon(Icons.screen_rotation),
      trailing: Switch(
        value: FullscreenAspect.enabled,
        onChanged: _busy ? null : _toggle,
      ),
    );
  }
}
