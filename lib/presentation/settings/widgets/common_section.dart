import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/settings/settings_bloc.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/core/locals.dart';
import 'package:fluxtube/core/model/language_model.dart';
import 'package:fluxtube/core/model/region_model.dart';
import 'package:fluxtube/core/regions.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/settings/widgets/new_video_notification_tile.dart';
import 'package:fluxtube/presentation/settings/widgets/window_fullscreen_tile.dart';
import 'package:go_router/go_router.dart';

List<DropdownMenuItem<String>> _getThemeModes(S locals) => [
  DropdownMenuItem(
    value: "system",
    child: Text(locals.themeSystem),
  ),
  DropdownMenuItem(
    value: "light",
    child: Text(locals.themeLight),
  ),
  DropdownMenuItem(
    value: "dark",
    child: Text(locals.themeDark),
  ),
  DropdownMenuItem(
    value: "oled",
    child: Text(locals.themeOled),
  ),
  DropdownMenuItem(
    value: "dynamic",
    child: Text(locals.themeDynamic),
  ),
];

class CommonSettingsSection extends StatelessWidget {
  const CommonSettingsSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final S locals = S.of(context);
    //change package to custom settings
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        // get language name by using language code
        final language = languages.firstWhere(
          (name) => name.code == state.defaultLanguage,
          orElse: () =>
              LanguageModel(name: locals.unknown, code: locals.unknown),
        );
        // get region name by using region code
        final region = regions.firstWhere(
          (name) => name.code == state.defaultRegion,
          orElse: () => RegionModel(name: locals.unknown, code: locals.unknown),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locals.commonSettingsTitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 16),
            ),
            kHeightBox10,
            ListTile(
              title: Text(locals.language,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(language.name),
              leading: const Icon(Icons.language),
              onTap: () => context.goNamed('languages'),
            ),
            ListTile(
              title: Text(locals.region,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(region.name),
              leading: const Icon(Icons.flag),
              onTap: () => context.goNamed('regions'),
            ),
            // Only show Instances option for services that use them (not NewPipe)
            if (state.ytService != YouTubeServices.newpipe.name)
              ListTile(
                title: Text(locals.instances,
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(state.instance),
                leading: const Icon(Icons.web_stories),
                onTap: () => context.goNamed('instances'),
              ),
            ListTile(
              title: Text(locals.theme,
                  style: Theme.of(context).textTheme.titleMedium),
              leading: const Icon(Icons.dark_mode_rounded),
              trailing: DropdownButton(
                  value: state.themeMode,
                  items: _getThemeModes(locals),
                  onChanged: (themeMode) =>
                      BlocProvider.of<SettingsBloc>(context).add(
                          SettingsEvent.changeTheme(
                              themeMode: themeMode.toString()))),
            ),
            const NewVideoNotificationTile(),
            const WindowFullscreenTile(),
          ],
        );
      },
    );
  }
}

// SettingsSection commonSettingsSection(S locals, BuildContext context,
//     LanguageModel language, RegionModel region, SettingsState state) {
//   return SettingsSection(
//     title: Text(
//       locals.commonSettingsTitle,
//       style: Theme.of(context).textTheme.bodyMedium,
//     ),
//     tiles: [
//       SettingsTile(
//         title: Text(locals.language),
//         description: Text(language.name),
//         leading: const Icon(Icons.language),
//         onPressed: (BuildContext ctx) => context.goNamed('languages'),
//       ),
//       SettingsTile(
//         title: Text(locals.region),
//         description: Text(region.name),
//         leading: const Icon(Icons.flag),
//         onPressed: (ctx) => context.goNamed('regions'),
//       ),
//       SettingsTile(
//         title: Text(locals.instances),
//         description: Text(state.instance),
//         leading: const Icon(Icons.web_stories),
//         onPressed: (ctx) => context.goNamed('instances'),
//       ),
//       SettingsTile(
//         title: Text(locals.theme),
//         leading: const Icon(Icons.dark_mode_rounded),
//         trailing: DropdownButton(
//             value: state.themeMode,
//             items: _themeModes,
//             onChanged: (themeMode) => BlocProvider.of<SettingsBloc>(context)
//                 .add(SettingsEvent.changeTheme(
//                     themeMode: themeMode.toString()))),
//       ),
//     ],
//   );
// }
