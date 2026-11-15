import 'package:field_shift/runtime/device_location.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_android/geolocator_android.dart';

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  const channel = MethodChannel('flutter.baseflow.com/geolocator_android');

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('asks for permission before reading approximate location', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'checkPermission':
          return LocationPermission.denied.index;
        case 'requestPermission':
          return LocationPermission.whileInUse.index;
        case 'getCurrentPosition':
          expect(call.arguments['accuracy'], LocationAccuracy.low.index);
          return {'latitude': -6.724, 'longitude': -79.777};
        default:
          throw UnsupportedError(call.method);
      }
    });

    final position = await requestAndroidLocation();
    expect(position?.toJson(), [-79.777, -6.724]);
    expect(calls, [
      'checkPermission',
      'requestPermission',
      'getCurrentPosition',
    ]);
  });

  test('a denied permission leaves the map in manual mode', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return LocationPermission.denied.index;
    });

    expect(await requestAndroidLocation(), isNull);
    expect(calls, ['checkPermission', 'requestPermission']);
  });

  test('a disabled Android location service returns no position', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'checkPermission') {
        return LocationPermission.whileInUse.index;
      }
      throw PlatformException(code: 'LOCATION_SERVICES_DISABLED');
    });

    expect(await requestAndroidLocation(), isNull);
    expect(calls, ['checkPermission', 'getCurrentPosition']);
  });
}
