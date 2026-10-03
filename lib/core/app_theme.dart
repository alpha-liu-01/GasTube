import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluxtube/core/colors.dart';

abstract class AppTheme {
  /// The official linux-arm64 engine is built without fontconfig. Its
  /// directory font manager returns no typeface from character fallback, so
  /// DejaVu and Roboto paint CJK as empty boxes. Naming a family that
  /// contains the glyphs makes `matchFamily` succeed. x64 still uses
  /// fontconfig and does not need this list. Droid Sans Fallback is bundled
  /// so a container without these system fonts can still draw Chinese.
  static const List<String> cjkFontFamilyFallback = <String>[
    'WenQuanYi Micro Hei',
    'WenQuanYi Zen Hei',
    'Noto Sans CJK SC',
    'Noto Sans CJK TC',
    'Noto Sans CJK HK',
    'Noto Sans CJK JP',
    'Noto Sans CJK KR',
    'Source Han Sans SC',
    'Source Han Sans TC',
    'Noto Sans SC',
    'Noto Sans TC',
    'Droid Sans Fallback',
  ];

  static TextStyle _withCjk(TextStyle style) =>
      style.copyWith(fontFamilyFallback: cjkFontFamilyFallback);

  /// Linux Material styles already set [TextStyle.fontFamilyFallback] to
  /// Ubuntu, DejaVu Sans, and Arial. [TextStyle.merge] keeps that list
  /// because it is non-null, so a theme-level fallback never reaches them.
  /// Styles we replace with a [TextStyle] that leaves the fallback null
  /// (bodyLarge and the italic bodySmall) keep the CJK list. That is why
  /// only those two showed Chinese.
  static TextTheme _cjkTheme(TextTheme theme) {
    TextStyle? apply(TextStyle? style) =>
        style == null ? null : _withCjk(style);
    return theme.copyWith(
      displayLarge: apply(theme.displayLarge),
      displayMedium: apply(theme.displayMedium),
      displaySmall: apply(theme.displaySmall),
      headlineLarge: apply(theme.headlineLarge),
      headlineMedium: apply(theme.headlineMedium),
      headlineSmall: apply(theme.headlineSmall),
      titleLarge: apply(theme.titleLarge),
      titleMedium: apply(theme.titleMedium),
      titleSmall: apply(theme.titleSmall),
      bodyLarge: apply(theme.bodyLarge),
      bodyMedium: apply(theme.bodyMedium),
      bodySmall: apply(theme.bodySmall),
      labelLarge: apply(theme.labelLarge),
      labelMedium: apply(theme.labelMedium),
      labelSmall: apply(theme.labelSmall),
    );
  }

  /// Cupertino styles set `inherit: false`, so they do not pick up the
  /// Material fallback list. Search uses [CupertinoSearchTextField].
  static Widget withCjkText(BuildContext context, Widget child) {
    final CupertinoThemeData cupertino = CupertinoTheme.of(context);
    final CupertinoTextThemeData textTheme = cupertino.textTheme;
    return CupertinoTheme(
      data: cupertino.copyWith(
        textTheme: textTheme.copyWith(
          textStyle: _withCjk(textTheme.textStyle),
          actionTextStyle: _withCjk(textTheme.actionTextStyle),
          actionSmallTextStyle: _withCjk(textTheme.actionSmallTextStyle),
          tabLabelTextStyle: _withCjk(textTheme.tabLabelTextStyle),
          navTitleTextStyle: _withCjk(textTheme.navTitleTextStyle),
          navLargeTitleTextStyle: _withCjk(textTheme.navLargeTitleTextStyle),
          navActionTextStyle: _withCjk(textTheme.navActionTextStyle),
          pickerTextStyle: _withCjk(textTheme.pickerTextStyle),
          dateTimePickerTextStyle: _withCjk(textTheme.dateTimePickerTextStyle),
        ),
      ),
      child: child,
    );
  }

  // Impeller's OpenGL ES backend (Linux, and ANGLE on Windows) crashes
  // painting a video Texture into a route snapshot.
  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(
        allowSnapshotting: false,
      ),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(
        allowSnapshotting: false,
      ),
    },
  );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamilyFallback: cjkFontFamilyFallback,
        pageTransitionsTheme: _pageTransitionsTheme,
        tabBarTheme: TabBarThemeData(indicatorColor: kGreyColor),
        primaryColorLight: kWhiteColor,
        primaryColorDark: kBlackColor,
        colorScheme: ColorScheme.fromSeed(seedColor: kBlackColor),
        primaryIconTheme: const IconThemeData().copyWith(color: kBlackColor),
        scaffoldBackgroundColor: kWhiteColor,
        textTheme: _cjkTheme(ThemeData.light().textTheme.copyWith(
              bodyLarge: const TextStyle(
                fontSize: 25,
                color: kBlackColor,
              ),
              bodySmall: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 15,
                color: kBlackColor,
              ),
            )),
        appBarTheme: const AppBarTheme(
            backgroundColor: kWhiteColor, foregroundColor: kBlackColor),
        iconTheme: const IconThemeData().copyWith(color: kGreyColor),
      );

  static ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      fontFamilyFallback: cjkFontFamilyFallback,
      pageTransitionsTheme: _pageTransitionsTheme,
      primaryColorLight: kWhiteColor,
      primaryColorDark: kBlackColor,
      tabBarTheme: TabBarThemeData(indicatorColor: kWhiteColor.withValues(alpha: 0.5)),
      primaryIconTheme: const IconThemeData().copyWith(color: kWhiteColor),
      colorScheme: const ColorScheme.dark(),
      scaffoldBackgroundColor: AppColors.surfaceDark,
      dividerTheme: const DividerThemeData().copyWith(color: kGreyOpacityColor),
      textTheme: _cjkTheme(ThemeData.dark().textTheme.copyWith(
            bodyLarge: const TextStyle(
              fontSize: 25,
              color: kWhiteColor,
            ),
            bodySmall: const TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 15,
              color: kWhiteColor,
            ),
          )),
      appBarTheme: AppBarTheme(
        backgroundColor: kBlackColor,
        foregroundColor: kWhiteColor,
        iconTheme: const IconThemeData().copyWith(color: kWhiteColor),
        actionsIconTheme: const IconThemeData().copyWith(color: kWhiteColor),
      ),
      iconTheme:
          const IconThemeData().copyWith(color: kWhiteColor.withValues(alpha: 0.7)),
      inputDecorationTheme: const InputDecorationTheme().copyWith(
        iconColor: kWhiteColor,
        prefixIconColor: kWhiteColor,
        suffixIconColor: kWhiteColor,
      ));

  static ThemeData get oledTheme => ThemeData(
      useMaterial3: true,
      fontFamilyFallback: cjkFontFamilyFallback,
      pageTransitionsTheme: _pageTransitionsTheme,
      brightness: Brightness.dark,
      primaryColorLight: kWhiteColor,
      primaryColorDark: const Color(0xFF000000),
      tabBarTheme: const TabBarThemeData(indicatorColor: Colors.white),
      primaryIconTheme: const IconThemeData().copyWith(color: kWhiteColor),
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF000000),
        onSurface: Colors.white,
        primary: Colors.white,
        onPrimary: Color(0xFF000000),
      ),
      scaffoldBackgroundColor: const Color(0xFF000000),
      dividerTheme: const DividerThemeData().copyWith(color: Colors.white12),
      textTheme: _cjkTheme(ThemeData.dark().textTheme.copyWith(
            bodyLarge: const TextStyle(fontSize: 25, color: kWhiteColor),
            bodySmall: const TextStyle(
                fontStyle: FontStyle.italic, fontSize: 15, color: kWhiteColor),
          )),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: kWhiteColor,
        elevation: 0,
        iconTheme: IconThemeData(color: kWhiteColor),
        actionsIconTheme: IconThemeData(color: kWhiteColor),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF000000),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
      ),
      iconTheme: const IconThemeData().copyWith(color: kWhiteColor.withValues(alpha: 0.7)),
      inputDecorationTheme: const InputDecorationTheme().copyWith(
        iconColor: kWhiteColor,
        prefixIconColor: kWhiteColor,
        suffixIconColor: kWhiteColor,
      ),
      cardColor: const Color(0xFF0A0A0A),
      dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF0A0A0A)),
    );

  static ThemeData dynamicTheme(ColorScheme colorScheme) => ThemeData(
        useMaterial3: true,
        fontFamilyFallback: cjkFontFamilyFallback,
        pageTransitionsTheme: _pageTransitionsTheme,
        colorScheme: colorScheme,
        tabBarTheme: TabBarThemeData(
            indicatorColor: colorScheme.onSurface.withValues(alpha: 0.6)),
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
          actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
        ),
        textTheme: _cjkTheme(ThemeData(
          brightness: colorScheme.brightness,
          useMaterial3: true,
        ).textTheme.copyWith(
              bodyLarge:
                  TextStyle(fontSize: 25, color: colorScheme.onSurface),
              bodySmall: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                  color: colorScheme.onSurface),
            )),
        iconTheme: IconThemeData(
            color: colorScheme.onSurface.withValues(alpha: 0.7)),
        dividerTheme: DividerThemeData(
            color: colorScheme.onSurface.withValues(alpha: 0.12)),
      );
}
