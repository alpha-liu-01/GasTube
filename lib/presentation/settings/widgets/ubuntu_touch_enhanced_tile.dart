import 'package:flutter/material.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:fluxtube/core/ubuntu_touch_content_hub.dart';
import 'package:fluxtube/generated/l10n.dart';

/// Master switch for behavior that needs Prevent app suspension.
///
/// The first step stops the resume helper this app starts itself. Desktop
/// builds do not show the row.
class UbuntuTouchEnhancedModeTile extends StatefulWidget {
  const UbuntuTouchEnhancedModeTile({super.key});

  @override
  State<UbuntuTouchEnhancedModeTile> createState() =>
      _UbuntuTouchEnhancedModeTileState();
}

class _UbuntuTouchEnhancedModeTileState
    extends State<UbuntuTouchEnhancedModeTile> {
  var _enabled = false;

  @override
  void initState() {
    super.initState();
    if (!UbuntuTouch.enabled) return;
    ubuntuTouchEnhancedMode().then((enabled) {
      if (!mounted) return;
      setState(() => _enabled = enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!UbuntuTouch.enabled) return const SizedBox.shrink();
    final locals = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kHeightBox15,
        Text(
          locals.ubuntuTouchEnhanced,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
        ),
        kHeightBox10,
        ListTile(
          title: Text(
            locals.ubuntuTouchEnhanced,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(locals.ubuntuTouchEnhancedDescription),
          leading: const Icon(Icons.stay_current_portrait),
          trailing: Switch(
            value: _enabled,
            onChanged: (enabled) async {
              setState(() => _enabled = enabled);
              await setUbuntuTouchEnhancedMode(enabled);
            },
          ),
        ),
      ],
    );
  }
}
