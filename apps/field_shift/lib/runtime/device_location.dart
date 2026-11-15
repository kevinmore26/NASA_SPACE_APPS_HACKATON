import 'dart:io';

import 'package:field_core/field_core.dart';
import 'package:geolocator_android/geolocator_android.dart';

final Future<GeoPoint?> Function()? requestLocation = Platform.isAndroid
    ? requestAndroidLocation
    : null;

Future<GeoPoint?> requestAndroidLocation() async {
  final locator = GeolocatorAndroid();
  try {
    var permission = await locator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await locator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    final fix = await locator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return GeoPoint(fix.latitude, fix.longitude);
  } on Object {
    return null;
  }
}
