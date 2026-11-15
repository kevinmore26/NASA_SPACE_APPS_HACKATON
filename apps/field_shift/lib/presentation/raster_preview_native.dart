import 'dart:io';

import 'package:flutter/painting.dart';

Future<ImageProvider?> loadRasterFile(String path) async {
  final file = File(path);
  return await file.exists() ? FileImage(file) : null;
}
