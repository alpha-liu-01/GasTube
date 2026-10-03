import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/settings/settings_bloc.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/settings.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/generated/l10n.dart';

List<DropdownMenuItem<String>> _getVideoCodecs() => const [
      DropdownMenuItem(value: defaultVideoCodecH264, child: Text('H.264')),
      DropdownMenuItem(value: defaultVideoCodecVp9, child: Text('VP9')),
    ];

List<DropdownMenuItem<String>> _getQualities(S locals) => [
  DropdownMenuItem(value: "144p", child: Text(locals.quality144p)),
  DropdownMenuItem(value: "240p", child: Text(locals.quality240p)),
  DropdownMenuItem(value: "360p", child: Text(locals.quality360p)),
  DropdownMenuItem(value: "480p", child: Text(locals.quality480p)),
  DropdownMenuItem(value: "720p", child: Text(locals.quality720p)),
  DropdownMenuItem(value: "1080p", child: Text(locals.quality1080p)),
  DropdownMenuItem(value: "1440p", child: Text(locals.quality1440p)),
];

List<DropdownMenuItem<YouTubeServices>> _getServices(S locals) {
  final services = <DropdownMenuItem<YouTubeServices>>[];

  services.add(DropdownMenuItem(
    value: YouTubeServices.newpipe,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(locals.serviceNewPipe),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '★',
            style: TextStyle(fontSize: 10, color: Colors.green),
          ),
        ),
      ],
    ),
  ));

  services.addAll([
    DropdownMenuItem(value: YouTubeServices.piped, child: Text(locals.servicePiped)),
    DropdownMenuItem(value: YouTubeServices.explode, child: Text(locals.serviceExplode)),
    DropdownMenuItem(value: YouTubeServices.invidious, child: Text(locals.serviceInvidious)),
  ]);

  return services;
}

List<DropdownMenuItem<String>> _getVideoFitModes(S locals) => [
  DropdownMenuItem(value: "contain", child: Text(locals.videoFitContain)),
  DropdownMenuItem(value: "cover", child: Text(locals.videoFitCover)),
  DropdownMenuItem(value: "fill", child: Text(locals.videoFitFill)),
  DropdownMenuItem(value: "fitWidth", child: Text(locals.videoFitFitWidth)),
  DropdownMenuItem(value: "fitHeight", child: Text(locals.videoFitFitHeight)),
];

List<DropdownMenuItem<int>> _getSkipIntervals(S locals) => [
  DropdownMenuItem(value: 5, child: Text("5 ${locals.seconds}")),
  DropdownMenuItem(value: 10, child: Text("10 ${locals.seconds}")),
  DropdownMenuItem(value: 15, child: Text("15 ${locals.seconds}")),
  DropdownMenuItem(value: 30, child: Text("30 ${locals.seconds}")),
  DropdownMenuItem(value: 60, child: Text("60 ${locals.seconds}")),
];

List<DropdownMenuItem<double>> _getSubtitleSizes(S locals) => [
  DropdownMenuItem(value: 24.0, child: Text(locals.subtitleSizeSmall)),
  DropdownMenuItem(value: 32.0, child: Text(locals.subtitleSizeMedium)),
  DropdownMenuItem(value: 42.0, child: Text(locals.subtitleSizeLarge)),
  DropdownMenuItem(value: 54.0, child: Text(locals.subtitleSizeExtraLarge)),
];

class VideoSettingsSection extends StatelessWidget {
  const VideoSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final locals = S.of(context);
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locals.video,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 16),
            ),
            kHeightBox10,
            ListTile(
              title: Text(locals.defaultQuality,
                  style: Theme.of(context).textTheme.titleMedium),
              leading: const Icon(Icons.hd_sharp),
              trailing: DropdownButton(
                  value: state.defaultQuality,
                  items: _getQualities(locals),
                  onChanged: (quality) => BlocProvider.of<SettingsBloc>(context)
                      .add(SettingsEvent.getDefaultQuality(
                          quality: quality.toString()))),
            ),
            ListTile(
              title: Text(locals.defaultVideoCodec,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(locals.defaultVideoCodecDescription),
              leading: const Icon(Icons.video_settings_outlined),
              trailing: DropdownButton<String>(
                value: normalizeDefaultVideoCodec(state.defaultVideoCodec),
                items: _getVideoCodecs(),
                onChanged: (codec) {
                  if (codec == null) return;
                  BlocProvider.of<SettingsBloc>(context).add(
                    SettingsEvent.setDefaultVideoCodec(codec: codec),
                  );
                },
              ),
            ),
            ListTile(
              title: Text(locals.youtubeService,
                  style: Theme.of(context).textTheme.titleMedium),
              leading: const Icon(Icons.network_cell),
              trailing: DropdownButton(
                  value: YouTubeServices.values
                      .firstWhere((e) => e.name == state.ytService),
                  items: _getServices(locals),
                  onChanged: (service) {
                    if (service == null) return;
                    final oldService = state.ytService;
                    BlocProvider.of<SettingsBloc>(context)
                        .add(SettingsEvent.setYTService(service: service));

                    // Only fetch instances for services that need them (not NewPipe)
                    if (service != YouTubeServices.newpipe) {
                      if (service == YouTubeServices.invidious) {
                        BlocProvider.of<SettingsBloc>(context)
                            .add(SettingsEvent.fetchInvidiousInstances());
                      } else {
                        BlocProvider.of<SettingsBloc>(context)
                            .add(SettingsEvent.fetchPipedInstances());
                      }
                    }

                    if (oldService != service.name) {
                      final serviceName = switch (service) {
                        YouTubeServices.newpipe => locals.serviceNewPipe,
                        YouTubeServices.piped => locals.servicePiped,
                        YouTubeServices.invidious => locals.serviceInvidious,
                        YouTubeServices.explode => locals.serviceExplode,
                      };
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Switched to $serviceName'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }),
            ),
            // Video Fit Mode
            ListTile(
              title: Text(locals.videoFit,
                  style: Theme.of(context).textTheme.titleMedium),
              leading: const Icon(Icons.aspect_ratio),
              trailing: DropdownButton(
                  value: state.videoFitMode,
                  items: _getVideoFitModes(locals),
                  onChanged: (fitMode) {
                    if (fitMode == null) return;
                    BlocProvider.of<SettingsBloc>(context)
                        .add(SettingsEvent.setVideoFitMode(fitMode: fitMode));
                  }),
            ),
            // Skip Interval
            ListTile(
              title: Text(locals.skipInterval,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(locals.skipIntervalDescription),
              leading: const Icon(Icons.fast_forward),
              trailing: DropdownButton(
                  value: state.skipInterval,
                  items: _getSkipIntervals(locals),
                  onChanged: (interval) {
                    if (interval == null) return;
                    BlocProvider.of<SettingsBloc>(context)
                        .add(SettingsEvent.setSkipInterval(seconds: interval));
                  }),
            ),
            // Subtitle Size
            ListTile(
              title: Text(locals.subtitleSize,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(locals.subtitleSizeDescription),
              leading: const Icon(Icons.subtitles),
              trailing: DropdownButton(
                  value: state.subtitleSize,
                  items: _getSubtitleSizes(locals),
                  onChanged: (size) {
                    if (size == null) return;
                    BlocProvider.of<SettingsBloc>(context)
                        .add(SettingsEvent.setSubtitleSize(size: size));
                  }),
            ),
            ListTile(
              title: Text(locals.hlsPlayer,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(locals.enableHlsPlayerDescription),
              leading: const Icon(CupertinoIcons.play),
              trailing: Switch(
                value: state.isHlsPlayer,
                onChanged: (_) {
                  BlocProvider.of<SettingsBloc>(context)
                      .add(SettingsEvent.toggleHlsPlayer());
                },
              ),
            ),
            ListTile(
              title: Text(locals.history,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(locals.disableVideoHistory),
              leading: const Icon(Icons.history),
              trailing: Switch(
                value: !state.isHistoryVisible,
                onChanged: (_) {
                  BlocProvider.of<SettingsBloc>(context)
                      .add(SettingsEvent.toggleHistoryVisibility());
                },
              ),
            ),
            ListTile(
              title: Text(locals.retrieveDislikes,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(locals.retrieveDislikeCounts),
              leading: const Icon(CupertinoIcons.hand_thumbsdown),
              trailing: Switch(
                value: state.isDislikeVisible,
                onChanged: (_) {
                  BlocProvider.of<SettingsBloc>(context)
                      .add(SettingsEvent.toggleDislikeVisibility());
                },
              ),
            ),
            ListTile(
              title: Text(locals.disablePipPlayer,
                  style: Theme.of(context).textTheme.titleMedium),
              leading: const Icon(Icons.picture_in_picture_alt),
              trailing: Switch(
                value: state.isPipDisabled,
                onChanged: (_) {
                  BlocProvider.of<SettingsBloc>(context)
                      .add(SettingsEvent.togglePipPlayer());
                },
              ),
            ),
            // Auto PiP - only available on Android
            if (Platform.isAndroid && !state.isPipDisabled)
              ListTile(
                title: Text(locals.autoPip,
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(locals.autoPipDescription),
                leading: const Icon(Icons.home),
                trailing: Switch(
                  value: state.isAutoPipEnabled,
                  onChanged: (_) {
                    BlocProvider.of<SettingsBloc>(context)
                        .add(SettingsEvent.toggleAutoPip());
                  },
                ),
              ),
            const Divider(),
            // Search History Privacy Settings
            ListTile(
              title: Text(locals.searchHistoryEnabled,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(locals.searchHistoryEnabledDescription),
              leading: const Icon(CupertinoIcons.doc_text_search),
              trailing: Switch(
                value: state.isSearchHistoryEnabled,
                onChanged: (_) {
                  BlocProvider.of<SettingsBloc>(context)
                      .add(SettingsEvent.toggleSearchHistoryEnabled());
                },
              ),
            ),
            if (state.isSearchHistoryEnabled)
              ListTile(
                title: Text(locals.showSearchHistory,
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(locals.showSearchHistoryDescription),
                leading: const Icon(CupertinoIcons.eye),
                trailing: Switch(
                  value: state.isSearchHistoryVisible,
                  onChanged: (_) {
                    BlocProvider.of<SettingsBloc>(context)
                        .add(SettingsEvent.toggleSearchHistoryVisibility());
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
