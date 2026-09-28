import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluxtube/core/colors.dart';

abstract class AppTheme {
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
        pageTransitionsTheme: _pageTransitionsTheme,
        tabBarTheme: TabBarThemeData(indicatorColor: kGreyColor),
        primaryColorLight: kWhiteColor,
        primaryColorDark: kBlackColor,
        colorScheme: ColorScheme.fromSeed(seedColor: kBlackColor),
        primaryIconTheme: const IconThemeData().copyWith(color: kBlackColor),
        scaffoldBackgroundColor: kWhiteColor,
        textTheme: ThemeData.light().textTheme.copyWith(
              bodyLarge: const TextStyle(
                fontSize: 25,
                color: kBlackColor,
              ),
              bodySmall: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 15,
                color: kBlackColor,
              ),
            ),
        appBarTheme: const AppBarTheme(
            backgroundColor: kWhiteColor, foregroundColor: kBlackColor),
        iconTheme: const IconThemeData().copyWith(color: kGreyColor),
      );

  static ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      primaryColorLight: kWhiteColor,
      primaryColorDark: kBlackColor,
      tabBarTheme: TabBarThemeData(indicatorColor: kWhiteColor.withValues(alpha: 0.5)),
      primaryIconTheme: const IconThemeData().copyWith(color: kWhiteColor),
      colorScheme: const ColorScheme.dark(),
      scaffoldBackgroundColor: kDarkColor,
      dividerTheme: const DividerThemeData().copyWith(color: kGreyOpacityColor),
      textTheme: ThemeData.dark().textTheme.copyWith(
            bodyLarge: const TextStyle(
              fontSize: 25,
              color: kWhiteColor,
            ),
            bodySmall: const TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 15,
              color: kWhiteColor,
            ),
          ),
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
      textTheme: ThemeData.dark().textTheme.copyWith(
            bodyLarge: const TextStyle(fontSize: 25, color: kWhiteColor),
            bodySmall: const TextStyle(
                fontStyle: FontStyle.italic, fontSize: 15, color: kWhiteColor),
          ),
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
        textTheme: ThemeData(
          brightness: colorScheme.brightness,
          useMaterial3: true,
        ).textTheme.copyWith(
              bodyLarge:
                  TextStyle(fontSize: 25, color: colorScheme.onSurface),
              bodySmall: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                  color: colorScheme.onSurface),
            ),
        iconTheme: IconThemeData(
            color: colorScheme.onSurface.withValues(alpha: 0.7)),
        dividerTheme: DividerThemeData(
            color: colorScheme.onSurface.withValues(alpha: 0.12)),
      );
}
