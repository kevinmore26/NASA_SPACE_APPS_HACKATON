import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import 'application/field_controller.dart';
import 'presentation/field_screen.dart';

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
  Widget build(BuildContext context) => MaterialApp(
    title: 'NASA Field Shift',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff185b3a)),
      scaffoldBackgroundColor: const Color(0xfff8faf7),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    ),
    home: FieldScreen(model: model, tiles: tiles, dataDirectory: dataDirectory),
  );
}
