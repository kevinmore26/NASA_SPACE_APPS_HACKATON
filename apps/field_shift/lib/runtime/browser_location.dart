import 'dart:async';
import 'dart:js_interop';

import 'package:field_core/field_core.dart';
import 'package:web/web.dart' as web;

Future<GeoPoint?> requestLocation() async {
  final result = Completer<GeoPoint?>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition position) {
        final coords = position.coords;
        try {
          result.complete(GeoPoint(coords.latitude, coords.longitude));
        } on ArgumentError {
          result.complete(null);
        }
      }).toJS,
      ((web.GeolocationPositionError _) => result.complete(null)).toJS,
      web.PositionOptions(
        enableHighAccuracy: false,
        timeout: 10000,
        maximumAge: 60000,
      ),
    );
  } on Object {
    return null;
  }
  return result.future;
}
