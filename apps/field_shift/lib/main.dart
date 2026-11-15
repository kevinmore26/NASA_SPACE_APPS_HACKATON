import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'runtime/open_native.dart'
    if (dart.library.js_interop) 'runtime/open_browser.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['IBM Plex Sans'], license);
    final photoCredits = await rootBundle.loadString(
      'assets/images/CREDITS.txt',
    );
    yield LicenseEntryWithLineBreaks(['Cover photograph'], photoCredits);
  });
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Opening saved fields…'),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    runApp(await openFieldShift());
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                kIsWeb
                    ? 'Could not open browser storage. Allow site storage and reload Field Shift.'
                    : 'Could not open local storage. Check your user folder permissions and reopen Field Shift.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
