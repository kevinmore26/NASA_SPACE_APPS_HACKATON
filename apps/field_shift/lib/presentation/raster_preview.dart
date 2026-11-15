import 'package:flutter/painting.dart';

import 'raster_preview_native.dart'
    if (dart.library.js_interop) 'raster_preview_browser.dart';

Future<ImageProvider?> loadRasterPreview(String value) async {
  if (value.startsWith('data:image/png;base64,')) {
    return MemoryImage(UriData.parse(value).contentAsBytes());
  }
  return loadRasterFile(value);
}
