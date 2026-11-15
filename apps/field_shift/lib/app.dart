import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import 'application/field_controller.dart';
import 'application/field_language.dart';
import 'presentation/field_screen.dart';
import 'presentation/workspace_widgets.dart';

class FieldShiftApp extends StatelessWidget {
  final FieldController model;
  final http.Client tiles;
  final String dataDirectory;

  const FieldShiftApp({
    super.key,
    required this.model,
    required this.tiles,
    required this.dataDirectory,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<FieldLanguage>(
    valueListenable: model.language,
    builder: (context, language, _) => MaterialApp(
      title: 'NASA Field Shift',
      debugShowCheckedModeBanner: false,
      locale: Locale(language.code),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _theme(),
      home: FieldScreen(
        model: model,
        tiles: tiles,
        dataDirectory: dataDirectory,
      ),
    ),
  );
}

ThemeData _theme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'IBM Plex Sans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: forest,
      primary: forest,
      surface: paper,
      primaryContainer: leaf,
      onPrimaryContainer: pine,
      onSurface: const Color(0xff203027),
    ),
    scaffoldBackgroundColor: canvas,
    appBarTheme: const AppBarThemeData(
      backgroundColor: canvas,
      foregroundColor: pine,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xffacb7a9)),
      ),
      filled: true,
      fillColor: const Color(0xfffafaf5),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: paper,
      foregroundColor: forest,
      elevation: 2,
      shape: CircleBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(46, 46)),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: pine,
        fontSize: 30,
        height: 1.16,
        letterSpacing: -0.9,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: pine,
        fontSize: 20,
        letterSpacing: -0.35,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: pine,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: 1.43,
        letterSpacing: 0,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ),
  );
}
