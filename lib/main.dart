import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluxtube/application/download/download_bloc.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/application/saved/saved_bloc.dart';
import 'package:fluxtube/application/settings/settings_bloc.dart';
import 'package:fluxtube/application/subscribe/subscribe_bloc.dart';
import 'package:fluxtube/application/trending/trending_bloc.dart';
import 'package:fluxtube/application/watch/watch_bloc.dart';
import 'package:fluxtube/core/app_info.dart';
import 'package:fluxtube/core/app_theme.dart';
import 'package:fluxtube/core/locals.dart';
import 'package:fluxtube/core/lomiri_theme.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/infrastructure/download/download_notification_service.dart';
import 'package:fluxtube/infrastructure/newpipe/newpipe_sidecar.dart';
import 'package:fluxtube/infrastructure/settings/setting_impl.dart';
import 'package:fluxtube/presentation/routes/app_routes.dart';
import 'package:fluxtube/presentation/routes/bloc_observer.dart';
import 'package:fluxtube/presentation/watch/widgets/global_pip_overlay.dart';
import 'package:fluxtube/core/services/audio_handler_service.dart';
import 'package:fluxtube/core/services/mpris_player.dart';
import 'package:fluxtube/core/services/log_collector.dart';
import 'package:fluxtube/core/services/subscription_notifier.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';
import 'package:fluxtube/core/ubuntu_touch_content_hub.dart';
import 'package:fluxtube/core/ubuntu_touch_frame_timing.dart';
import 'package:fluxtube/core/ubuntu_touch_image_cache.dart';
import 'package:fluxtube/core/window_fullscreen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:screen_brightness/screen_brightness.dart';

import 'core/di/injectable.dart';

void main(List<String> args) async {
  if (UbuntuTouch.enabled) {
    for (final arg in args) {
      if (UbuntuTouchUrls.isLaunchArgument(arg)) {
        UbuntuTouchUrls.argv.add(arg);
        print('gastube: url argv $arg');
      }
    }
  }
  WidgetsFlutterBinding.ensureInitialized();
  installUbuntuTouchFrameTiming();
  installUbuntuTouchImageCache();

  // Mirror framework debug output into the in-app log collector so the Debug
  // Console can surface it for bug reports. LogCollector re-emits through
  // dart:developer, so console output is preserved.
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      LogCollector().log(message, tag: 'FLUTTER');
    }
  };

  // Ubuntu Touch loads the libmpv shipped beside the executable. Desktop
  // builds keep the system library.
  if (UbuntuTouch.enabled) {
    unawaited(startUbuntuTouchContentHub());
    final libmpv = p.join(
      p.dirname(Platform.resolvedExecutable),
      'lib',
      'libmpv.so.2',
    );
    MediaKit.ensureInitialized(libmpv: libmpv);
    debugPrint('gastube: libmpv $libmpv');
  } else {
    MediaKit.ensureInitialized();
  }

  // screen_brightness_windows re-reads monitor brightness on every window
  // resize and focus change. That fails on displays without DDC/CI and logs
  // "Problem getting monitor brightness" each time. The app never changes
  // brightness on Windows.
  if (Platform.isWindows) {
    unawaited(ScreenBrightness.instance.setAutoReset(false));
  }

  // Allow up to 200 MB for decoded image bitmaps (default is 100 MB)
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;

  Bloc.observer = AppBlocObserver();
  await SettingImpl.initializeDB();
  // Initialize GetIt and register dependencies
  configureInjection();

  final Brightness? lomiriBrightness =
      UbuntuTouch.enabled ? await LomiriSystemTheme.read() : null;
  runApp(MyApp(lomiriBrightness: lomiriBrightness));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.lomiriBrightness});

  final Brightness? lomiriBrightness;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Brightness? _lomiriBrightness;
  bool _loggedDynamicColor = false;
  bool _loggedPlatformBrightness = false;

  @override
  void initState() {
    super.initState();
    _lomiriBrightness = widget.lomiriBrightness;
    WidgetsBinding.instance.addObserver(this);
    _logPlatformBrightness();
    // Initialize services after the first frame
    // This ensures the Activity is fully attached and can show permission dialogs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (UbuntuTouch.enabled) {
        final view = View.of(context);
        final logical = view.physicalSize / view.devicePixelRatio;
        stderr.writeln(
          'gastube: logical=${logical.width.toStringAsFixed(1)}x'
          '${logical.height.toStringAsFixed(1)} '
          'physical=${view.physicalSize.width.toStringAsFixed(0)}x'
          '${view.physicalSize.height.toStringAsFixed(0)} '
          'dpr=${view.devicePixelRatio} '
          'padding=${view.padding}',
        );
      }
      if (!UbuntuTouch.enabled) {
        DownloadNotificationService().initialize();
        WindowFullscreen.loadAndApply();
      }
      if (!Platform.isLinux) {
        initAudioService();
      } else {
        unawaited(MprisPlayer.instance.claim());
      }
      // Look for new uploads from subscribed channels. Self-throttling and a
      // no-op unless the user turned notifications on.
      SubscriptionNotifier().checkForNewVideos();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose the global player when app is closing
    GlobalPlayerController().disposePlayer();
    NewPipeSidecar.instance.shutdown();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app is detached (being destroyed), stop the player to prevent crash
    if (state == AppLifecycleState.detached) {
      GlobalPlayerController().disposePlayer();
      NewPipeSidecar.instance.shutdown();
    }
    // Returning to the foreground is the only chance to poll for new uploads,
    // since there is no background job. The check throttles itself.
    if (state == AppLifecycleState.resumed) {
      SubscriptionNotifier().checkForNewVideos();
      _refreshLomiriTheme();
    }
  }

  void _logPlatformBrightness() {
    if (!UbuntuTouch.enabled || _loggedPlatformBrightness) return;
    _loggedPlatformBrightness = true;
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    print(
      'gastube: platform brightness=$platform '
      'lomiri=${LomiriSystemTheme.lastName} '
      'brightness=$_lomiriBrightness',
    );
  }

  Future<void> _refreshLomiriTheme() async {
    if (!UbuntuTouch.enabled) return;
    final brightness = await LomiriSystemTheme.read();
    if (!mounted) return;
    _logPlatformBrightness();
    if (brightness == _lomiriBrightness) return;
    setState(() => _lomiriBrightness = brightness);
  }

  ThemeMode _themeModeFor(String themeMode) {
    switch (themeMode) {
      case 'dark':
      case 'oled':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        if (!UbuntuTouch.enabled || _lomiriBrightness == null) {
          return ThemeMode.system;
        }
        return _lomiriBrightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<TrendingBloc>()),
        BlocProvider(create: (context) => getIt<WatchBloc>()),
        BlocProvider(create: (context) => getIt<SettingsBloc>()),
        BlocProvider(create: (context) => getIt<SavedBloc>()),
        BlocProvider(create: (context) => getIt<SubscribeBloc>()),
        BlocProvider(create: (context) => getIt<DownloadBloc>()),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        buildWhen: (previous, current) =>
            previous.themeMode != current.themeMode ||
            previous.defaultLanguage != current.defaultLanguage,
        builder: (context, state) {
          final mode = state.themeMode;

          if (mode == 'dynamic') {
            return DynamicColorBuilder(
              builder: (lightDynamic, darkDynamic) {
                if (UbuntuTouch.enabled &&
                    !_loggedDynamicColor &&
                    lightDynamic == null &&
                    darkDynamic == null) {
                  _loggedDynamicColor = true;
                  print(
                    'gastube: dynamic color unavailable, using the seed fallback',
                  );
                }
                return MaterialApp.router(
                  title: AppInfo.myApp.name,
                  theme: AppTheme.dynamicTheme(lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.blue)),
                  darkTheme: AppTheme.dynamicTheme(darkDynamic ?? const ColorScheme.dark()),
                  themeMode: _themeModeFor(mode),
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    S.delegate,
                  ],
                  supportedLocales: supportedLocales,
                  locale: Locale(state.defaultLanguage),
                  builder: (context, child) {
                    return AppTheme.withCjkText(
                      context,
                      GlobalPipOverlay(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    );
                  },
                );
              },
            );
          }

          final isOled = mode == 'oled';
          return MaterialApp.router(
            title: AppInfo.myApp.name,
            theme: AppTheme.lightTheme,
            darkTheme: isOled ? AppTheme.oledTheme : AppTheme.darkTheme,
            themeMode: _themeModeFor(mode),
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              S.delegate,
            ],
            supportedLocales: supportedLocales,
            locale: Locale(state.defaultLanguage),
            builder: (context, child) {
              return AppTheme.withCjkText(
                context,
                GlobalPipOverlay(
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        },
      ),
    );
  }

}
